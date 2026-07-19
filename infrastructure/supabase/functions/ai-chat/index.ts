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

interface RequestBody {
  chatId: string;
  workspaceId?: string | null;
}

interface ContextItem {
  id: string;
  label: string;
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

    const { systemPrompt, sourceReferences } = await buildSystemPrompt(
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
    if (!replyText) {
      console.error("ai-chat: risposta Anthropic senza testo", anthropicBody);
      return jsonError("Il servizio AI ha restituito una risposta vuota.", 502);
    }

    const { error: insertError } = await supabase.from("messages").insert({
      chat_id: body.chatId,
      role: "ai",
      content: replyText,
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
): Promise<{ systemPrompt: string; sourceReferences: string[] }> {
  if (!workspaceId) {
    return { systemPrompt: ASSISTANT_PERSONA, sourceReferences: [] };
  }

  const { data: workspace } = await supabase
    .from("workspaces")
    .select("name, description")
    .eq("id", workspaceId)
    .maybeSingle();

  if (!workspace) {
    // L'utente non ha accesso a questo Workspace (RLS) o non esiste più: rispondi
    // senza contesto invece di fallire l'intero turno.
    return { systemPrompt: ASSISTANT_PERSONA, sourceReferences: [] };
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

  const sections: string[] = [
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

  const systemPrompt = `${ASSISTANT_PERSONA}\n\n${sections.join("\n\n")}`;
  const sourceReferences = [...noteItems, ...taskItems, ...documentItems].map((
    i,
  ) => i.id);

  return { systemPrompt, sourceReferences };
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

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}
