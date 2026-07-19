// AI Engine — unico punto di contatto con il provider AI (CLAUDE.md, AGENTS.md
// paragrafo 4: nessun altro modulo chiama direttamente un provider LLM).
//
// Riceve { chatId, workspaceId? }: il messaggio dell'utente è già stato inserito in
// `messages` dal client prima di questa chiamata (apps/mobile,
// SupabaseMessageRepository.sendMessage). Questa function costruisce il contesto,
// chiama Claude, e inserisce la risposta come nuova riga `messages` — il client la
// riceve tramite la sottoscrizione realtime già esistente, non dalla risposta HTTP.
//
// Usa sempre il JWT di chi chiama, mai la service role: le stesse RLS di
// chats/messages/workspaces/notes/tasks/documents (infrastructure/supabase/migrations)
// si applicano identiche qui dentro — stesso principio "security invoker" già
// verificato per search_workspace_content. Questa function non ha alcun modo di
// leggere dati di un Workspace che l'utente non possiede.

import { createClient } from "npm:@supabase/supabase-js@2";

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";
const MAX_OUTPUT_TOKENS = 1024;
const MAX_HISTORY_MESSAGES = 20;
const MAX_CONTEXT_ITEMS = 5;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Sintesi di docs/product/13-prompt-engineering.md e docs/product/21-ai-constitution.md:
// il system prompt tecnico è la traduzione operativa di quei due capitoli, non una
// terza lista di regole scollegata.
const ASSISTANT_PERSONA =
  `Sei l'assistente AI di Personal Intelligence Platform (PIP).
Sei un collaboratore, non un chatbot: ogni risposta deve aiutare l'utente a comprendere,
decidere, organizzare, agire.

Stile: professionale, chiaro, sintetico quando possibile, approfondito quando richiesto.
Proattivo ma mai invadente. Trasparente sui tuoi limiti.

Non inventare informazioni. Non simulare certezze che non hai. Non prendere decisioni al
posto dell'utente. Se le informazioni nel contesto sono incomplete, dichiaralo e spiega
cosa manca invece di colmare i vuoti con supposizioni presentate come fatti.

Quando la risposta si basa su Note, Attività o Documenti del Workspace elencati nel
contesto, indicalo esplicitamente (a quale nota/attività/documento ti riferisci).`;

// Addendum al system prompt, solo quando è disponibile un Workspace reale (vedi
// `transactionToolEnabled` in buildSystemPrompt): istruisce l'uso dello strumento
// extract_transactions e richiede sempre una risposta testuale di conferma, così
// l'utente può controllare a colpo d'occhio l'importo estratto prima di
// confermarlo (AI Constitution, Principio 5 — nessuna falsa certezza).
const TRANSACTION_TOOL_INSTRUCTIONS =
  `Quando l'utente descrive una o più spese o entrate già avvenute (es. "barbiere 23€,
supermercato 35€" oppure "ho ricevuto lo stipendio di 1500€"), usa lo strumento
extract_transactions per registrarle — non limitarti a scriverle in prosa. Le transazioni
estratte restano "in attesa di conferma" finché l'utente non le conferma esplicitamente nella
schermata Bilancio del Workspace: non contano ancora nel saldo. Includi sempre, oltre
all'eventuale uso dello strumento, una risposta testuale breve che nomini cosa hai registrato
(tipo, descrizione e importo di ciascuna transazione) e che è in attesa di conferma.`;

// Nome e schema dello strumento Anthropic per l'estrazione strutturata di spese ed
// entrate (Fase 3 slice 2 — vedi docs/database/README.md). Niente `currency`: questa
// slice registra sempre in EUR. Attaccato alla richiesta solo quando esiste un
// Workspace reale a cui collegare le transazioni (vedi `transactionToolEnabled`).
const EXTRACT_TRANSACTIONS_TOOL = {
  name: "extract_transactions",
  description:
    "Registra una o più transazioni personali (spese o entrate) che l'utente descrive " +
    "esplicitamente come già avvenute (es. 'ho speso 23€ dal barbiere', 'ho ricevuto lo " +
    "stipendio di 1500€'). Non usarlo per importi futuri, preventivi, stime o ipotesi.",
  input_schema: {
    type: "object",
    properties: {
      transactions: {
        type: "array",
        items: {
          type: "object",
          properties: {
            type: {
              type: "string",
              enum: ["income", "expense"],
              description: "'income' per un'entrata, 'expense' per un'uscita.",
            },
            description: {
              type: "string",
              description: "Breve descrizione, es. 'Barbiere' o 'Stipendio'.",
            },
            amount_cents: {
              type: "integer",
              description:
                "Importo in centesimi, sempre positivo (es. 23,00€ = 2300).",
            },
            occurred_at: {
              type: "string",
              description:
                "Data della transazione in formato YYYY-MM-DD. Se l'utente indica solo un " +
                "mese, usa il giorno 1 di quel mese, nell'anno corrente rispetto alla data " +
                "odierna fornita nel contesto.",
            },
          },
          required: ["type", "description", "amount_cents", "occurred_at"],
        },
      },
    },
    required: ["transactions"],
  },
};

interface RequestBody {
  chatId: string;
  workspaceId?: string | null;
}

interface ContextItem {
  id: string;
  label: string;
}

interface TransactionSuggestion {
  type: "income" | "expense";
  description: string;
  amountCents: number;
  occurredAt: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonError("Autenticazione mancante.", 401);
    }

    const body = (await req.json()) as Partial<RequestBody>;
    if (!body.chatId) {
      return jsonError("chatId obbligatorio.", 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const anthropicApiKey = Deno.env.get("ANTHROPIC_API_KEY");

    if (!supabaseUrl || !supabaseAnonKey || !anthropicApiKey) {
      console.error(
        "ai-chat: variabili d'ambiente mancanti (SUPABASE_URL/ANON_KEY/ANTHROPIC_API_KEY)",
      );
      return jsonError("Servizio AI non configurato.", 500);
    }

    // Client con il JWT dell'utente: tutte le query qui sotto sono soggette a RLS
    // esattamente come se le facesse l'app mobile.
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: chat, error: chatError } = await supabase
      .from("chats")
      .select("id, ai_model")
      .eq("id", body.chatId)
      .single();

    if (chatError || !chat) {
      return jsonError("Chat non trovata.", 404);
    }

    const { data: historyRows, error: historyError } = await supabase
      .from("messages")
      .select("role, content")
      .eq("chat_id", body.chatId)
      .order("created_at", { ascending: true })
      .limit(MAX_HISTORY_MESSAGES);

    if (historyError) {
      console.error("ai-chat: errore lettura messages", historyError);
      return jsonError("Non è stato possibile leggere la conversazione.", 500);
    }

    const { systemPrompt, sourceReferences, transactionToolEnabled } =
      await buildSystemPrompt(
        supabase,
        body.workspaceId ?? null,
      );

    const anthropicMessages = (historyRows ?? [])
      .filter((row) => row.role === "user" || row.role === "ai")
      .map((row) => ({
        role: row.role === "ai" ? "assistant" : "user",
        content: row.content as string,
      }));

    if (anthropicMessages.length === 0) {
      return jsonError("Nessun messaggio da elaborare.", 400);
    }

    const anthropicResponse = await fetch(ANTHROPIC_API_URL, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": anthropicApiKey,
        "anthropic-version": ANTHROPIC_VERSION,
      },
      body: JSON.stringify({
        model: chat.ai_model,
        max_tokens: MAX_OUTPUT_TOKENS,
        system: systemPrompt,
        messages: anthropicMessages,
        ...(transactionToolEnabled
          ? { tools: [EXTRACT_TRANSACTIONS_TOOL] }
          : {}),
      }),
    });

    if (!anthropicResponse.ok) {
      const detail = await anthropicResponse.text();
      console.error(
        "ai-chat: errore Anthropic",
        anthropicResponse.status,
        detail,
      );
      return jsonError("Il servizio AI non è disponibile al momento.", 502);
    }

    const anthropicBody = await anthropicResponse.json();
    const replyText = extractText(anthropicBody);

    const suggestions = transactionToolEnabled
      ? extractTransactionSuggestions(anthropicBody)
        .map(sanitizeTransaction)
        .filter((s): s is TransactionSuggestion => s !== null)
      : [];

    let transactionInsertFailed = false;
    if (suggestions.length > 0) {
      const { error: transactionInsertError } = await supabase.from(
        "transactions",
      )
        .insert(
          suggestions.map((s) => ({
            workspace_id: body.workspaceId,
            chat_id: body.chatId,
            type: s.type,
            description: s.description,
            amount_cents: s.amountCents,
            occurred_at: s.occurredAt,
            status: "pending",
            created_by_ai: true,
          })),
        );
      if (transactionInsertError) {
        console.error(
          "ai-chat: errore insert transactions",
          transactionInsertError,
        );
        transactionInsertFailed = true;
      }
    }

    // Il testo finale non deve mai affermare un successo che non c'è stato: se
    // l'insert delle transazioni fallisce, lo diciamo esplicitamente invece di
    // lasciare che la risposta del modello (scritta prima di sapere se l'insert
    // sarebbe riuscito) suggerisca il contrario.
    let finalReplyText = replyText;
    if (transactionInsertFailed) {
      finalReplyText =
        "Non sono riuscito a salvare le transazioni rilevate: riprova." +
        (replyText ? `\n\n${replyText}` : "");
    } else if (!finalReplyText && suggestions.length > 0) {
      finalReplyText = `Ho registrato ${suggestions.length} ${
        suggestions.length === 1 ? "transazione" : "transazioni"
      } in attesa di conferma nella sezione Bilancio.`;
    }

    if (!finalReplyText) {
      console.error("ai-chat: risposta Anthropic senza testo", anthropicBody);
      return jsonError("Il servizio AI ha restituito una risposta vuota.", 502);
    }

    const { error: insertError } = await supabase.from("messages").insert({
      chat_id: body.chatId,
      role: "ai",
      content: finalReplyText,
      tokens_used: anthropicBody?.usage?.output_tokens ?? null,
      source_references: sourceReferences,
    });

    if (insertError) {
      console.error("ai-chat: errore insert risposta", insertError);
      return jsonError("Non è stato possibile salvare la risposta.", 500);
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...CORS_HEADERS, "content-type": "application/json" },
    });
  } catch (error) {
    console.error("ai-chat: errore inatteso", error);
    return jsonError("Si è verificato un problema imprevisto.", 500);
  }
});

/// Contesto Workspace per euristica (Note/Task/Documenti più recenti — non ricerca
/// semantica/embeddings, coerente con lo scope ridotto descritto in
/// docs/product/26-execution-blueprint.md per la Fase 3). Ritorna anche gli id usati,
/// per popolare `source_references` (trasparenza, AI Constitution Principio 3).
async function buildSystemPrompt(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  workspaceId: string | null,
): Promise<
  {
    systemPrompt: string;
    sourceReferences: string[];
    transactionToolEnabled: boolean;
  }
> {
  if (!workspaceId) {
    // Una Chat senza Workspace non ha dove collegare una transazione: niente strumento.
    return {
      systemPrompt: ASSISTANT_PERSONA,
      sourceReferences: [],
      transactionToolEnabled: false,
    };
  }

  const { data: workspace } = await supabase
    .from("workspaces")
    .select("name, description")
    .eq("id", workspaceId)
    .maybeSingle();

  if (!workspace) {
    // L'utente non ha accesso a questo Workspace (RLS) o non esiste più: rispondi
    // senza contesto invece di fallire l'intero turno. Nessuno strumento transazioni:
    // non c'è un Workspace verificato a cui collegarle (difesa in profondità oltre a RLS).
    return {
      systemPrompt: ASSISTANT_PERSONA,
      sourceReferences: [],
      transactionToolEnabled: false,
    };
  }

  const [{ data: notes }, { data: tasks }, { data: documents }] = await Promise
    .all([
      supabase
        .from("notes")
        .select("id, title, content")
        .eq("workspace_id", workspaceId)
        .is("deleted_at", null)
        .order("updated_at", { ascending: false })
        .limit(MAX_CONTEXT_ITEMS),
      supabase
        .from("tasks")
        .select("id, title, status")
        .eq("workspace_id", workspaceId)
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(MAX_CONTEXT_ITEMS),
      supabase
        .from("documents")
        .select("id, name")
        .eq("workspace_id", workspaceId)
        .is("deleted_at", null)
        .order("uploaded_at", { ascending: false })
        .limit(MAX_CONTEXT_ITEMS),
    ]);

  const noteItems: ContextItem[] = (notes ?? []).map(
    (n: { id: string; title: string; content: string }) => ({
      id: n.id,
      label: `- ${n.title}${n.content ? `: ${n.content.slice(0, 200)}` : ""}`,
    }),
  );
  const taskItems: ContextItem[] = (tasks ?? []).map(
    (t: { id: string; title: string; status: string }) => ({
      id: t.id,
      label: `- ${t.title} (${t.status})`,
    }),
  );
  const documentItems: ContextItem[] = (documents ?? []).map(
    (d: { id: string; name: string }) => ({ id: d.id, label: `- ${d.name}` }),
  );

  // "Data odierna" dà al modello un riferimento affidabile per risolvere date
  // relative ("questo mese", "il mese scorso") quando estrae le transazioni.
  const today = new Date().toISOString().slice(0, 10);
  const sections: string[] = [
    `Data odierna: ${today}.`,
    `Workspace attivo: "${workspace.name}"${
      workspace.description ? ` — ${workspace.description}` : ""
    }`,
  ];
  if (noteItems.length > 0) {
    sections.push(`Note recenti:\n${noteItems.map((i) => i.label).join("\n")}`);
  }
  if (taskItems.length > 0) {
    sections.push(
      `Attività recenti:\n${taskItems.map((i) => i.label).join("\n")}`,
    );
  }
  if (documentItems.length > 0) {
    sections.push(
      `Documenti recenti:\n${documentItems.map((i) => i.label).join("\n")}`,
    );
  }

  const systemPrompt =
    `${ASSISTANT_PERSONA}\n\n${TRANSACTION_TOOL_INSTRUCTIONS}\n\n${
      sections.join("\n\n")
    }`;
  const sourceReferences = [...noteItems, ...taskItems, ...documentItems].map((
    i,
  ) => i.id);

  return { systemPrompt, sourceReferences, transactionToolEnabled: true };
}

// deno-lint-ignore no-explicit-any
function extractText(anthropicBody: any): string | null {
  const blocks = anthropicBody?.content;
  if (!Array.isArray(blocks)) return null;
  const text = blocks
    .filter((block: { type: string; text?: string }) =>
      block.type === "text" && block.text
    )
    .map((block: { text: string }) => block.text)
    .join("\n")
    .trim();
  return text.length > 0 ? text : null;
}

// Estrae le chiamate allo strumento extract_transactions dalla risposta Anthropic.
// Un turno può contenere sia un blocco `text` sia uno o più blocchi `tool_use`
// (tool_choice di default è "auto": il modello decide se/quando usarlo).
// deno-lint-ignore no-explicit-any
function extractTransactionSuggestions(anthropicBody: any): unknown[] {
  const blocks = anthropicBody?.content;
  if (!Array.isArray(blocks)) return [];
  return blocks
    .filter((block: { type: string; name?: string }) =>
      block.type === "tool_use" && block.name === "extract_transactions"
    )
    // deno-lint-ignore no-explicit-any
    .flatMap((block: any) =>
      Array.isArray(block.input?.transactions) ? block.input.transactions : []
    );
}

// Validazione difensiva: lo schema del tool vincola la forma del JSON, non la sua
// correttezza — un valore strutturalmente valido ma sbagliato (es. importo 0, data
// non parsabile, tipo diverso da income/expense) va scartato qui, non solo delegato
// al check constraint del DB.
function sanitizeTransaction(raw: unknown): TransactionSuggestion | null {
  if (typeof raw !== "object" || raw === null) return null;
  const r = raw as Record<string, unknown>;
  const type = r.type === "income" || r.type === "expense" ? r.type : null;
  const description = typeof r.description === "string"
    ? r.description.trim()
    : "";
  const amountCents = Math.round(Number(r.amount_cents));
  const occurredAt = typeof r.occurred_at === "string" ? r.occurred_at : "";
  if (!type) return null;
  if (!description) return null;
  if (!Number.isFinite(amountCents) || amountCents <= 0) return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(occurredAt)) return null;
  return { type, description, amountCents, occurredAt };
}

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}
