// AI Engine — unico punto di contatto con il provider AI (CLAUDE.md, AGENTS.md
// paragrafo 4: nessun altro modulo chiama direttamente un provider LLM).
//
// Riceve { chatId, workspaceId?, remindersWorkspaceId? }: il messaggio dell'utente è già inserito in
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
//
// Oltre a estrarre transazioni/promemoria da un messaggio, può anche rispondere a
// domande sui dati reali dell'utente ("quanto ho speso questo mese", "ho appuntamenti il
// mese prossimo") tramite due strumenti di sola lettura (query_balance_summary,
// query_reminders) sempre disponibili: quando il modello li usa, questa function esegue
// la query sotto RLS e fa un secondo giro con Anthropic per ottenere una risposta in
// prosa basata sul risultato reale (vedi buildSystemPrompt/QUERY_TOOL_INSTRUCTIONS e il
// ramo `queryToolUseBlocks.length > 0` più sotto).

import { createClient } from "npm:@supabase/supabase-js@2";

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";
// 1024 si è rivelato insufficiente in produzione: senza `thinking: disabled`,
// il modello può usare l'intero budget in ragionamento esteso interno prima
// di scrivere anche solo un token di risposta visibile (osservato: 1024
// thinking_tokens, stop_reason "max_tokens", nessun blocco di testo) — una
// chat conversazionale non ha bisogno di quel ragionamento, quindi va
// disabilitato esplicitamente (vedi la chiamata a fetch più sotto) invece di
// limitarsi ad alzare il tetto e rimandare lo stesso problema.
const MAX_OUTPUT_TOKENS = 2048;
const MAX_HISTORY_MESSAGES = 20;
const MAX_CONTEXT_ITEMS = 5;
// Memorie globali iniettate nel contesto (vedi buildSystemPrompt): un limite più
// alto di MAX_CONTEXT_ITEMS perché sono frasi brevi e riguardano l'utente in
// generale, non un singolo Workspace — restano utili anche se numerose.
const MAX_MEMORY_ITEMS = 20;

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
contesto, indicalo esplicitamente (a quale nota/attività/documento ti riferisci).

Se l'utente allega una foto, guardala e usala per rispondere (es. leggi uno scontrino, descrivi
un documento, riconosci un oggetto) invece di ignorarla.

Usa emoji pertinenti nelle tue risposte, con naturalezza (stile chat, non un'emoji per frase):
aiutano a rendere la conversazione più calda e leggibile. Non forzarle quando il contenuto è
serio o delicato (es. un errore, un dato finanziario critico, un argomento sensibile).

Non hai pulsanti di suggerimento nell'interfaccia: se è naturale nel contesto, proponi tu a
parole cosa l'utente potrebbe fare dopo (es. "Vuoi che te lo ricordi?", "Vuoi che lo aggiunga
alla lista?", "Vuoi sapere quanto hai speso questo mese?") invece di aspettare che formuli la
richiesta esatta da solo — con la stessa naturalezza di un collaboratore che anticipa un bisogno,
non una lista fissa di opzioni ripetuta a ogni risposta.

Nelle tue risposte puoi usare **testo in grassetto** (per enfasi su un dato o un termine chiave)
ed elenchi puntati con una riga che inizia per "- " (per due o più opzioni/passaggi): vengono
resi correttamente nell'interfaccia. Usali solo quando aiutano davvero la leggibilità, non in
ogni risposta — una frase breve non ha bisogno di formattazione.`;

// Addendum al system prompt, solo quando è disponibile un Workspace reale (vedi
// `transactionToolEnabled` in buildSystemPrompt): istruisce l'uso dello strumento
// extract_transactions e richiede sempre una risposta testuale di conferma, così
// l'utente può controllare a colpo d'occhio l'importo estratto prima di
// confermarlo (AI Constitution, Principio 5 — nessuna falsa certezza).
const TRANSACTION_TOOL_INSTRUCTIONS =
  `Quando l'utente descrive una o più spese o entrate già avvenute (es. "barbiere 23€,
supermercato 35€" oppure "ho ricevuto lo stipendio di 1500€"), usa lo strumento
extract_transactions per registrarle — non limitarti a scriverle in prosa. Classifica ogni
transazione nella categoria più adatta tra quelle disponibili nello schema dello strumento (es.
"barbiere" è "svago", "supermercato" è "alimentari", uno stipendio è "stipendio"): se nessuna
categoria specifica calza, usa "altro" — non lasciare il campo indeciso. Le transazioni estratte
restano "in attesa di conferma" finché l'utente non le conferma esplicitamente nella sezione
Bilancio: non contano ancora nel saldo. Includi sempre, oltre all'eventuale uso dello strumento,
una risposta testuale breve che nomini cosa hai registrato (tipo, descrizione e importo di
ciascuna transazione) e che è in attesa di conferma.`;

// Addendum al system prompt, solo quando è disponibile un Workspace reale (stesso gate di
// TRANSACTION_TOOL_INSTRUCTIONS — vedi `transactionToolEnabled`): richiesta esplicita
// dell'utente, "spese ricorrenti automatiche", stesso motore già costruito per i
// Promemoria ricorrenti (REMINDER_TOOL_INSTRUCTIONS). A differenza di extract_transactions
// (una transazione già avvenuta, subito pending), create_recurring_transaction registra un
// modello: la Edge Function `create-due-recurring-transactions` genera una nuova
// transazione pending ogni volta che è dovuta, non tutte insieme in anticipo.
const RECURRING_TRANSACTION_TOOL_INSTRUCTIONS =
  `Quando l'utente descrive una spesa o un'entrata che si ripete nel tempo (es. "il canone
Netflix è 15,99€ ogni mese", "pago l'affitto di 800€ il primo di ogni mese", "ricevo 200€ ogni
settimana di mancia"), usa lo strumento create_recurring_transaction — non extract_transactions,
che è solo per un evento già avvenuto una tantum. Risolvi la data della prima occorrenza rispetto
alla data odierna fornita nel contesto (se l'utente non la specifica, usa oggi). Classifica la
categoria con lo stesso criterio di extract_transactions. Includi sempre, oltre all'uso dello
strumento, una risposta testuale breve che confermi importo, frequenza e che le occorrenze future
compariranno "in attesa di conferma" quando dovute, non tutte insieme.`;

// Nome e schema dello strumento Anthropic per l'estrazione strutturata di spese ed
// entrate (Fase 3 slice 2 — vedi docs/database/README.md). Niente `currency`: questa
// slice registra sempre in EUR. Attaccato alla richiesta solo quando esiste un
// Workspace reale a cui collegare le transazioni (vedi `transactionToolEnabled`).
// Set fisso, coerente con packages/domain TransactionCategory (Fase 3, slice 7C — "Bilancio
// con categorie"). Se lo schema cambia va cambiato in entrambi i posti: nessuna condivisione
// di tipi tra Dart e TypeScript in questo progetto.
const TRANSACTION_CATEGORIES = [
  "alimentari",
  "trasporti",
  "casa",
  "bollette",
  "salute",
  "svago",
  "shopping",
  "istruzione",
  "stipendio",
  "altro",
] as const;

// Modello usato per la lettura isolata di uno scontrino (handleExtractReceipt): a
// differenza del resto della Chat, questa modalità non è legata a una riga `chats`
// (nessun `ai_model` da leggere), quindi serve un default fisso — stesso valore di
// `kDefaultAiModel` in apps/mobile/lib/features/chat/data/supabase_chat_repository.dart
// (duplicato invece di condiviso, stessa convenzione già usata per TRANSACTION_CATEGORIES
// tra Dart e TypeScript).
const RECEIPT_EXTRACTION_MODEL = "claude-sonnet-5";

// System prompt della lettura isolata di uno scontrino: forza l'uso di
// extract_transactions (tool_choice, non "auto") perché qui serve sempre un risultato
// strutturato da precompilare nel form, mai una risposta in prosa.
const RECEIPT_EXTRACTION_SYSTEM_PROMPT =
  `Analizza la foto di uno scontrino o di una ricevuta allegata e registrala con lo strumento
extract_transactions. Usa sempre type "expense" (uno scontrino non rappresenta mai un'entrata).
La descrizione è il nome del negozio/esercizio se leggibile nella foto, altrimenti una breve
descrizione degli articoli principali. L'importo è il totale pagato, non un singolo articolo. Se
la data non è leggibile nella foto, usa la data odierna fornita nel contesto. Classifica la
categoria con lo stesso criterio del resto della Chat (es. supermercato → "alimentari",
ristorante/bar → "svago", farmacia → "salute", benzina → "trasporti"). Se la foto non mostra
affatto uno scontrino o una ricevuta (nessun importo/negozio leggibile), usa comunque lo
strumento ma con amount_cents 0 — verrà scartato lato server invece di registrare dati
inventati.`;

// Addendum al system prompt, solo quando è disponibile un Workspace per i promemoria
// (vedi `reminderToolEnabled`): a differenza delle Transazioni, un promemoria non ha
// uno stato "pending/confirmed" — non è un dato finanziario da poter contare per
// errore, ed è banalmente reversibile (si cancella con un tocco) — inserito
// direttamente, con una risposta testuale di conferma (stesso principio di
// trasparenza, non lo stesso meccanismo di conferma delle Transazioni).
const REMINDER_TOOL_INSTRUCTIONS =
  `Quando l'utente chiede di essere ricordato di qualcosa in un momento specifico nel
futuro (es. "ricordami la visita dal dentista giovedì alle 15", "promemoria: chiamare Mario
domani alle 10"), usa lo strumento create_reminder per registrarlo — non limitarti a scriverlo
in prosa. Usa la data odierna fornita nel contesto per risolvere date/orari relativi. Non usarlo
per eventi già avvenuti, task senza un orario specifico, o richieste vaghe senza un momento
preciso. Se l'utente chiede esplicitamente una ripetizione (es. "ogni lunedì", "ogni giorno",
"ogni mese"), valorizza il campo recurrence invece di creare più promemoria manualmente: le
occorrenze successive vengono generate automaticamente. Includi sempre, oltre all'uso dello
strumento, una risposta testuale breve che confermi cosa hai registrato, quando, e se è
ricorrente.`;

// Addendum al system prompt, solo quando è disponibile un Workspace per le Attività
// (vedi `taskToolEnabled`): richiesta esplicita dell'utente, "Liste/checklist via
// Chat" (Slice C del piano originale, mai realizzata finora). Stesso ragionamento di
// REMINDER_TOOL_INSTRUCTIONS: un elemento di lista non ha uno stato "pending/
// confirmed" — è reversibile con un tocco (si elimina come qualsiasi Task), non un
// dato finanziario da dover contare con cautela.
const TASK_TOOL_INSTRUCTIONS =
  `Quando l'utente chiede di aggiungere uno o più elementi a una lista/checklist (es.
"aggiungi alla lista spesa: latte, pane, uova" oppure "segna da fare: chiamare il
commercialista"), usa lo strumento manage_tasks per registrarli come Attività — non
limitarti a scriverli in prosa. Un elemento per voce della lista, non un'unica Attività con
tutti gli elementi nel titolo. Non usarlo per impegni con un orario preciso (usa
create_reminder) o per spese/entrate (usa extract_transactions). Includi sempre, oltre
all'uso dello strumento, una risposta testuale breve che confermi cosa hai aggiunto.`;

// Addendum al system prompt, sempre presente (Fase 3, "Chat come Home" —
// richiesta esplicita dell'utente: "qualsiasi domanda che riguardi le
// informazioni al suo interno"): a differenza di extract_transactions/
// create_reminder, questi due strumenti sono di sola lettura e non dipendono
// da un Workspace attivo — funzionano in qualunque conversazione, perché
// leggono sempre sotto RLS solo i dati del chiamante.
// Addendum al system prompt, sempre presente come QUERY_TOOL_INSTRUCTIONS (Domain
// Model, entità Memory — prima slice minima, richiesta esplicita dell'utente):
// a differenza di extract_transactions/create_reminder/manage_tasks, non dipende da
// un Workspace attivo — la Memoria è legata all'utente, non a un Workspace o una Chat
// specifica (vedi MemoryLevel.global in packages/domain).
const REMEMBER_FACT_TOOL_INSTRUCTIONS =
  `Quando l'utente chiede esplicitamente di ricordare un'informazione per il futuro (es.
"ricorda che...", "tieni a mente che...", "d'ora in poi ricordati che..."), usa lo strumento
remember_fact per salvarla — non limitarti a scriverla in prosa. Scrivi il contenuto come un
fatto autonomo in terza persona (es. "Preferisce il caffè la mattina"), senza includere "ricorda
che" nel testo salvato. Non usarlo per impegni con una scadenza specifica (usa create_reminder) o
per elementi di una lista (usa manage_tasks). Includi sempre, oltre all'uso dello strumento, una
risposta testuale breve che confermi cosa hai memorizzato.`;

const QUERY_TOOL_INSTRUCTIONS =
  `Quando l'utente fa una domanda che richiede di conoscere i suoi dati reali (es. "quanto ho
speso questo mese", "quante entrate ci sono state", "quanto ho speso in alimentari ad aprile",
"ho appuntamenti il mese prossimo", "cosa ho in agenda questa settimana"), usa lo strumento
query_balance_summary (spese/entrate/saldo) o query_reminders (promemoria/appuntamenti) invece di
rispondere a memoria o inventare un numero (AI Constitution, "non inventare informazioni").
Risolvi il periodo richiesto in date concrete (period_start/period_end, formato YYYY-MM-DD)
usando la data odierna fornita nel contesto. Dopo aver ricevuto il risultato dello strumento,
rispondi SEMPRE dichiarando esplicitamente il totale richiesto in una frase diretta (es. "Hai
speso 340,00€ questo mese" oppure "Hai avuto 3 entrate per un totale di 1.500,00€") — non
limitarti a elencare le singole transazioni o i singoli promemoria: l'utente ha chiesto un
riepilogo, non un elenco. Un elenco puntuale delle voci (poche righe) può seguire il totale come
dettaglio aggiuntivo, ma il totale deve comparire per primo ed essere inequivocabile.`;

const QUERY_BALANCE_SUMMARY_TOOL = {
  name: "query_balance_summary",
  description:
    "Restituisce il riepilogo di entrate/uscite confermate del Bilancio personale (esclude i " +
    "Bilanci condivisi) per un periodo, con il dettaglio per categoria di spesa. Usalo per " +
    "domande come 'quanto ho speso questo mese' o 'quanto ho speso in alimentari ad aprile'.",
  input_schema: {
    type: "object",
    properties: {
      period_start: {
        type: "string",
        description: "Inizio del periodo, formato YYYY-MM-DD (incluso).",
      },
      period_end: {
        type: "string",
        description: "Fine del periodo, formato YYYY-MM-DD (incluso).",
      },
    },
    required: ["period_start", "period_end"],
  },
};

const QUERY_REMINDERS_TOOL = {
  name: "query_reminders",
  description:
    "Restituisce i promemoria/appuntamenti non cancellati in un periodo. Usalo per domande come " +
    "'ho appuntamenti il mese prossimo' o 'cosa ho in agenda questa settimana'.",
  input_schema: {
    type: "object",
    properties: {
      period_start: {
        type: "string",
        description: "Inizio del periodo, formato YYYY-MM-DD (incluso).",
      },
      period_end: {
        type: "string",
        description: "Fine del periodo, formato YYYY-MM-DD (incluso).",
      },
    },
    required: ["period_start", "period_end"],
  },
};

// Numero di occorrenze generate per ciascuna frequenza (richiesta esplicita
// dell'utente: "promemoria ricorrenti", es. "ogni lunedì", "ogni mese") — un limite
// fisso, non deciso dal modello: evita inserimenti incontrollati se il modello
// interpretasse "ricordamelo sempre" alla lettera. Corrisponde a orizzonti
// paragonabili nel tempo (14 giorni, ~14 settimane, 12 mesi).
const RECURRENCE_OCCURRENCES: Record<string, number> = {
  daily: 14,
  weekly: 14,
  monthly: 12,
};

const CREATE_REMINDER_TOOL = {
  name: "create_reminder",
  description:
    "Crea un promemoria per un momento specifico nel futuro, quando l'utente chiede " +
    "esplicitamente di essere ricordato di qualcosa (es. 'ricordami la visita dal dentista " +
    "giovedì alle 15', 'ricordami ogni lunedì di buttare la spazzatura'). Non usarlo per " +
    "eventi già avvenuti o senza un orario preciso.",
  input_schema: {
    type: "object",
    properties: {
      title: {
        type: "string",
        description: "Breve descrizione del promemoria, es. 'Visita dal dentista'.",
      },
      starts_at: {
        type: "string",
        description:
          "Data e ora della PRIMA occorrenza del promemoria in formato ISO 8601 (es. " +
          "'2026-07-24T15:00:00'), risolta rispetto alla data odierna fornita nel contesto.",
      },
      reminder_minutes_before: {
        type: "integer",
        description:
          "Minuti di anticipo per l'avviso rispetto a starts_at (facoltativo, default 0 " +
          "= avviso esattamente all'orario indicato).",
      },
      recurrence: {
        type: "string",
        enum: ["none", "daily", "weekly", "monthly"],
        description:
          "'none' (default) per un promemoria singolo. 'daily'/'weekly'/'monthly' se " +
          "l'utente chiede esplicitamente una ripetizione (es. 'ogni giorno'/'ogni " +
          "lunedì'/'ogni mese') — genera automaticamente le occorrenze successive, non " +
          "serve calcolarle.",
      },
    },
    required: ["title", "starts_at"],
  },
};

const MANAGE_TASKS_TOOL = {
  name: "manage_tasks",
  description:
    "Aggiunge uno o più elementi a una lista/checklist come Attività (es. 'aggiungi alla " +
    "lista spesa: latte, pane, uova'). Un elemento per voce — non un'unica Attività con " +
    "tutta la lista nel titolo.",
  input_schema: {
    type: "object",
    properties: {
      items: {
        type: "array",
        items: {
          type: "string",
          description: "Titolo breve di un singolo elemento, es. 'Latte'.",
        },
      },
    },
    required: ["items"],
  },
};

const REMEMBER_FACT_TOOL = {
  name: "remember_fact",
  description:
    "Salva un'informazione che l'utente chiede esplicitamente di ricordare per le " +
    "conversazioni future (es. 'ricorda che sono vegetariano', 'ricorda che il mio " +
    "compleanno è il 3 marzo'). Non usarlo per impegni con una scadenza specifica " +
    "(usa create_reminder) o per elementi di una lista (usa manage_tasks).",
  input_schema: {
    type: "object",
    properties: {
      content: {
        type: "string",
        description:
          "L'informazione da ricordare, in una frase breve e autonoma in terza persona " +
          "(es. 'È vegetariano', non 'Ricorda che è vegetariano').",
      },
    },
    required: ["content"],
  },
};

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
            category: {
              type: "string",
              enum: TRANSACTION_CATEGORIES,
              description:
                "Categoria più adatta (es. 'barbiere' → 'svago', 'supermercato' → " +
                "'alimentari', uno stipendio → 'stipendio'). Usa 'altro' solo se nessuna " +
                "categoria più specifica calza.",
            },
          },
          required: [
            "type",
            "description",
            "amount_cents",
            "occurred_at",
            "category",
          ],
        },
      },
    },
    required: ["transactions"],
  },
};

const CREATE_RECURRING_TRANSACTION_TOOL = {
  name: "create_recurring_transaction",
  description:
    "Registra un modello di spesa o entrata che si ripete nel tempo (es. 'il canone " +
    "Netflix è 15,99€ ogni mese'), non un evento già avvenuto una tantum (per quello usa " +
    "extract_transactions). Le occorrenze future compaiono 'in attesa di conferma' quando " +
    "dovute, non tutte insieme.",
  input_schema: {
    type: "object",
    properties: {
      type: {
        type: "string",
        enum: ["income", "expense"],
        description: "'income' per un'entrata, 'expense' per un'uscita.",
      },
      description: {
        type: "string",
        description: "Breve descrizione, es. 'Netflix' o 'Affitto'.",
      },
      amount_cents: {
        type: "integer",
        description: "Importo in centesimi, sempre positivo (es. 15,99€ = 1599).",
      },
      category: {
        type: "string",
        enum: TRANSACTION_CATEGORIES,
        description:
          "Categoria più adatta, stesso criterio di extract_transactions. Usa 'altro' " +
          "solo se nessuna categoria più specifica calza.",
      },
      frequency: {
        type: "string",
        enum: ["weekly", "monthly"],
        description: "'weekly' o 'monthly', in base a come l'utente descrive la ricorrenza.",
      },
      first_occurrence_at: {
        type: "string",
        description:
          "Data della PRIMA occorrenza in formato YYYY-MM-DD, risolta rispetto alla data " +
          "odierna fornita nel contesto. Se l'utente non la specifica, usa la data odierna.",
      },
    },
    required: ["type", "description", "amount_cents", "category", "frequency", "first_occurrence_at"],
  },
};

interface RequestBody {
  chatId: string;
  workspaceId?: string | null;
  // Sezione "Appuntamenti" (SystemWorkspaceCategory in packages/domain) — separata da
  // `workspaceId` (sempre la sezione Bilancio, vedi apps/mobile ChatHomeScreen): un
  // promemoria non appartiene mai al Workspace delle transazioni.
  remindersWorkspaceId?: string | null;
  // Sezione "Attività" — separata sia da `workspaceId` che da `remindersWorkspaceId`: un
  // elemento di lista (manage_tasks) non appartiene né al Bilancio né agli Appuntamenti.
  tasksWorkspaceId?: string | null;
  // Lettura isolata di uno scontrino già caricato (Fase 3, "OCR sugli scontrini
  // allegati manualmente" — integrazione richiesta esplicitamente): quando presente,
  // nessuno degli altri campi/della logica di Chat viene usato — vedi
  // `handleExtractReceipt` più sotto. Mai combinato con `chatId` nella stessa
  // richiesta: il client li invoca come due modalità distinte.
  extractReceiptDocumentId?: string;
}

interface ContextItem {
  id: string;
  label: string;
}

type TransactionCategory = typeof TRANSACTION_CATEGORIES[number];

interface TransactionSuggestion {
  type: "income" | "expense";
  description: string;
  amountCents: number;
  occurredAt: string;
  category: TransactionCategory;
}

// Solo weekly/monthly (a differenza di RecurrenceFrequency dei Promemoria, che include
// anche daily): una spesa/entrata giornaliera automatica non ha un caso d'uso realistico.
type TransactionRecurrenceFrequency = "weekly" | "monthly";

interface RecurringTransactionSuggestion {
  type: "income" | "expense";
  description: string;
  amountCents: number;
  category: TransactionCategory;
  frequency: TransactionRecurrenceFrequency;
  firstOccurrenceAt: string;
}

type RecurrenceFrequency = "daily" | "weekly" | "monthly";

interface ReminderSuggestion {
  title: string;
  startsAt: string;
  reminderMinutesBefore: number | null;
  recurrence: RecurrenceFrequency | null;
}

interface ReminderRow {
  workspace_id: string | null | undefined;
  source_chat_id: string | undefined;
  title: string;
  starts_at: string;
  reminder_minutes_before: number | null;
  recurrence_group_id: string | null;
}

interface TaskSuggestion {
  title: string;
}

interface MemorySuggestion {
  content: string;
}

interface AnthropicTextBlock {
  type: "text";
  text: string;
}

interface AnthropicImageBlock {
  type: "image";
  source: { type: "base64"; media_type: string; data: string };
}

type AnthropicContentBlock = AnthropicTextBlock | AnthropicImageBlock;

// Solo l'ultimo messaggio dell'utente può includere immagini (non l'intera
// cronologia, per contenere costo/latenza — vedi buildAnthropicMessages).
const MAX_IMAGE_ATTACHMENTS = 3;
// Limite prudenziale per immagine, coerente con i limiti pratici di Anthropic
// per contenuto base64 in un singolo messaggio.
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

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

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const anthropicApiKey = Deno.env.get("ANTHROPIC_API_KEY");

    if (!supabaseUrl || !supabaseAnonKey || !anthropicApiKey) {
      console.error(
        "ai-chat: variabili d'ambiente mancanti (SUPABASE_URL/ANON_KEY/ANTHROPIC_API_KEY)",
      );
      return jsonError("Servizio AI non configurato.", 500);
    }

    // Modalità isolata "leggi uno scontrino" (vedi RequestBody.extractReceiptDocumentId):
    // esce subito, prima di richiedere/usare `chatId` — nessuna riga `messages` coinvolta.
    if (body.extractReceiptDocumentId) {
      const supabaseForReceipt = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      return await handleExtractReceipt(
        supabaseForReceipt,
        anthropicApiKey,
        body.extractReceiptDocumentId,
      );
    }

    if (!body.chatId) {
      return jsonError("chatId obbligatorio.", 400);
    }

    // Client con il JWT dell'utente: tutte le query qui sotto sono soggette a RLS
    // esattamente come se le facesse l'app mobile.
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    // Serve solo per valorizzare memories.user_id all'inserimento (remember_fact):
    // nessun privilegio aggiuntivo, `getUser` legge lo stesso JWT già usato per
    // ogni altra query di questa function.
    const { data: userData } = await supabase.auth.getUser();
    const currentUserId: string | null = userData?.user?.id ?? null;

    const { data: chat, error: chatError } = await supabase
      .from("chats")
      .select("id, ai_model")
      .eq("id", body.chatId)
      .single();

    if (chatError || !chat) {
      return jsonError("Chat non trovata.", 404);
    }

    // Ordine decrescente + limite, poi si ripristina l'ordine cronologico
    // sotto: `ascending + limit` prenderebbe i primi N messaggi della chat
    // (i più vecchi), non gli ultimi — con una conversazione più lunga di
    // MAX_HISTORY_MESSAGES, quella finestra "congelata" nel passato può
    // finire su una riga dell'assistente, e Anthropic rifiuta una richiesta
    // la cui cronologia non termina con un messaggio dell'utente (errore
    // "invalid_request_error": "This model does not support assistant
    // message prefill").
    const { data: historyRowsDesc, error: historyError } = await supabase
      .from("messages")
      .select("role, content, attachment_ids")
      .eq("chat_id", body.chatId)
      .order("created_at", { ascending: false })
      .limit(MAX_HISTORY_MESSAGES);

    if (historyError) {
      console.error("ai-chat: errore lettura messages", historyError);
      return jsonError("Non è stato possibile leggere la conversazione.", 500);
    }

    const historyRows = (historyRowsDesc ?? []).slice().reverse();

    const {
      systemPrompt,
      sourceReferences,
      transactionToolEnabled,
      reminderToolEnabled,
      taskToolEnabled,
    } = await buildSystemPrompt(
      supabase,
      body.workspaceId ?? null,
      body.remindersWorkspaceId ?? null,
      body.tasksWorkspaceId ?? null,
    );

    const anthropicMessages = await buildAnthropicMessages(
      supabase,
      historyRows,
    );

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
        // Un assistente conversazionale non ha bisogno di ragionamento esteso
        // interno: disabilitato esplicitamente, non solo omesso, perché senza
        // questo il modello può comunque usarlo di sua iniziativa (vedi
        // commento su MAX_OUTPUT_TOKENS più sopra).
        thinking: { type: "disabled" },
        // query_balance_summary/query_reminders sono sempre presenti (a differenza di
        // extract_transactions/create_reminder/manage_tasks, che restano condizionati al
        // Workspace attivo).
        tools: [
          ...(transactionToolEnabled ? [EXTRACT_TRANSACTIONS_TOOL] : []),
          ...(transactionToolEnabled ? [CREATE_RECURRING_TRANSACTION_TOOL] : []),
          ...(reminderToolEnabled ? [CREATE_REMINDER_TOOL] : []),
          ...(taskToolEnabled ? [MANAGE_TASKS_TOOL] : []),
          REMEMBER_FACT_TOOL,
          QUERY_BALANCE_SUMMARY_TOOL,
          QUERY_REMINDERS_TOOL,
        ],
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
    let replyText = extractText(anthropicBody);

    // Se il modello ha usato uno dei due strumenti di sola lettura, serve un secondo
    // giro di andata/ritorno con Anthropic: solo dopo aver eseguito la query e restituito
    // il risultato reale, il modello può scrivere una risposta in prosa che lo citi (non
    // può farlo nello stesso turno in cui chiede il dato). Un solo giro di follow-up,
    // mai più di uno: la richiesta qui sotto non porta `tools`, quindi il modello non può
    // chiedere un'altra chiamata.
    const toolUseBlocks = extractToolUseBlocks(anthropicBody);
    const queryToolUseBlocks = toolUseBlocks.filter((block) =>
      block.name === "query_balance_summary" || block.name === "query_reminders"
    );

    if (queryToolUseBlocks.length > 0) {
      const toolResults = await Promise.all(toolUseBlocks.map(async (block) => {
        if (block.name === "query_balance_summary") {
          const result = await queryBalanceSummary(supabase, block.input);
          return {
            type: "tool_result",
            tool_use_id: block.id,
            content: JSON.stringify(result),
          };
        }
        if (block.name === "query_reminders") {
          const result = await queryReminders(supabase, block.input);
          return {
            type: "tool_result",
            tool_use_id: block.id,
            content: JSON.stringify(result),
          };
        }
        // extract_transactions/create_reminder: l'inserimento reale nel DB avviene più
        // sotto, indipendentemente da questo secondo turno — qui serve solo un
        // tool_result "di cortesia" per soddisfare il contratto dell'API Anthropic (ogni
        // tool_use della risposta precedente deve avere un tool_result corrispondente).
        return {
          type: "tool_result",
          tool_use_id: block.id,
          content: JSON.stringify({ status: "ricevuto" }),
        };
      }));

      const followUpMessages: { role: string; content: unknown }[] = [
        ...anthropicMessages,
        { role: "assistant", content: anthropicBody.content },
        { role: "user", content: toolResults },
      ];

      const followUpResponse = await fetch(ANTHROPIC_API_URL, {
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
          messages: followUpMessages,
          thinking: { type: "disabled" },
        }),
      });

      if (!followUpResponse.ok) {
        const detail = await followUpResponse.text();
        console.error(
          "ai-chat: errore Anthropic (follow-up)",
          followUpResponse.status,
          detail,
        );
        return jsonError("Il servizio AI non è disponibile al momento.", 502);
      }

      const followUpBody = await followUpResponse.json();
      replyText = extractText(followUpBody) ?? replyText;
    }

    const suggestions = transactionToolEnabled
      ? extractTransactionSuggestions(anthropicBody)
        .map(sanitizeTransaction)
        .filter((s): s is TransactionSuggestion => s !== null)
      : [];

    let transactionInsertFailed = false;
    // Id delle transazioni appena inserite (richiesta esplicita dell'utente: "Conferma/
    // Scarta inline in Chat") — salvati sul messaggio più sotto, per permettere alla
    // Chat di mostrare le azioni rapide senza dover risalire al Bilancio.
    let insertedTransactionIds: string[] = [];
    if (suggestions.length > 0) {
      const { data: insertedTransactions, error: transactionInsertError } =
        await supabase.from(
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
              category: s.category,
            })),
          )
          .select("id");
      if (transactionInsertError) {
        console.error(
          "ai-chat: errore insert transactions",
          transactionInsertError,
        );
        transactionInsertFailed = true;
      } else {
        insertedTransactionIds = (insertedTransactions ?? []).map(
          (t: { id: string }) => t.id,
        );
      }
    }

    // Spese/entrate ricorrenti automatiche (richiesta esplicita dell'utente): registra
    // un MODELLO (recurring_transaction_templates), non tutte le occorrenze future come
    // Transazioni pending — vedi il commento in cima al file della migrazione. Se la
    // prima occorrenza è già dovuta (oggi o nel passato), la prima Transaction pending
    // viene inserita subito qui, senza aspettare il prossimo giro del cron job
    // `create-due-recurring-transactions` (una volta al giorno) — coerente con la
    // reattività del resto della Chat; le occorrenze successive restano al cron.
    const recurringTransactionSuggestions = transactionToolEnabled
      ? extractRecurringTransactionSuggestions(anthropicBody)
        .map(sanitizeRecurringTransaction)
        .filter((r): r is RecurringTransactionSuggestion => r !== null)
      : [];

    let recurringTransactionInsertFailed = false;
    if (recurringTransactionSuggestions.length > 0) {
      const todayIso = new Date().toISOString().slice(0, 10);
      const immediateTransactionRows: Record<string, unknown>[] = [];
      const templateRows: Record<string, unknown>[] = [];

      for (const suggestion of recurringTransactionSuggestions) {
        const anchorDay = Number(suggestion.firstOccurrenceAt.slice(8, 10));
        let nextOccurrenceAt = suggestion.firstOccurrenceAt;
        if (suggestion.firstOccurrenceAt <= todayIso) {
          immediateTransactionRows.push({
            workspace_id: body.workspaceId,
            chat_id: body.chatId,
            type: suggestion.type,
            description: suggestion.description,
            amount_cents: suggestion.amountCents,
            occurred_at: suggestion.firstOccurrenceAt,
            status: "pending",
            created_by_ai: true,
            category: suggestion.category,
          });
          nextOccurrenceAt = advanceRecurringOccurrence(
            suggestion.firstOccurrenceAt,
            suggestion.frequency,
            anchorDay,
          );
        }
        templateRows.push({
          workspace_id: body.workspaceId,
          type: suggestion.type,
          description: suggestion.description,
          amount_cents: suggestion.amountCents,
          category: suggestion.category,
          frequency: suggestion.frequency,
          next_occurrence_at: nextOccurrenceAt,
          anchor_day: anchorDay,
        });
      }

      if (immediateTransactionRows.length > 0) {
        const { data: insertedRecurringTransactions, error: immediateInsertError } =
          await supabase.from("transactions").insert(immediateTransactionRows).select(
            "id",
          );
        if (immediateInsertError) {
          console.error(
            "ai-chat: errore insert transactions (ricorrenti)",
            immediateInsertError,
          );
          recurringTransactionInsertFailed = true;
        } else {
          insertedTransactionIds = insertedTransactionIds.concat(
            (insertedRecurringTransactions ?? []).map((t: { id: string }) => t.id),
          );
        }
      }

      const { error: templateInsertError } = await supabase.from(
        "recurring_transaction_templates",
      ).insert(templateRows);
      if (templateInsertError) {
        console.error(
          "ai-chat: errore insert recurring_transaction_templates",
          templateInsertError,
        );
        recurringTransactionInsertFailed = true;
      }
    }

    // A differenza delle Transazioni (pending/confirmed), un promemoria non ha nulla
    // da confermare: reversibile con un tocco, non un dato finanziario — inserito
    // direttamente (AI Constitution, Principio 1 si applica al "contare" qualcosa,
    // non a un promemoria che si cancella con un tap).
    const reminderSuggestions = reminderToolEnabled
      ? extractReminderSuggestions(anthropicBody)
        .map(sanitizeReminder)
        .filter((r): r is ReminderSuggestion => r !== null)
      : [];

    let reminderInsertFailed = false;
    // Una riga per occorrenza (richiesta esplicita dell'utente: "promemoria
    // ricorrenti") — un solo `recurrence_group_id` per suggerimento, condiviso da
    // tutte le sue occorrenze, per poterle mostrare come un'unica serie in UI senza
    // toccare send-due-reminders (che continua a vedere righe indipendenti).
    const reminderRows: ReminderRow[] = reminderSuggestions.flatMap((r) => {
      if (r.recurrence === null) {
        const single: ReminderRow = {
          workspace_id: body.remindersWorkspaceId,
          source_chat_id: body.chatId,
          title: r.title,
          starts_at: r.startsAt,
          reminder_minutes_before: r.reminderMinutesBefore,
          recurrence_group_id: null,
        };
        return [single];
      }
      const recurrenceGroupId: string = crypto.randomUUID();
      return expandOccurrences(new Date(r.startsAt), r.recurrence).map(
        (occurrence): ReminderRow => ({
          workspace_id: body.remindersWorkspaceId,
          source_chat_id: body.chatId,
          title: r.title,
          starts_at: occurrence.toISOString(),
          reminder_minutes_before: r.reminderMinutesBefore,
          recurrence_group_id: recurrenceGroupId,
        }),
      );
    });

    if (reminderRows.length > 0) {
      const { error: reminderInsertError } = await supabase.from(
        "calendar_events",
      )
        .insert(reminderRows);
      if (reminderInsertError) {
        console.error(
          "ai-chat: errore insert calendar_events",
          reminderInsertError,
        );
        reminderInsertFailed = true;
      }
    }

    // Un elemento di lista, come un promemoria, non ha stato pending/confirmed:
    // reversibile con un tocco (si elimina come qualsiasi Task), inserito direttamente
    // (richiesta esplicita dell'utente: "Liste/checklist via Chat").
    const taskSuggestions = taskToolEnabled
      ? extractTaskSuggestions(anthropicBody)
        .map(sanitizeTask)
        .filter((t): t is TaskSuggestion => t !== null)
      : [];

    let taskInsertFailed = false;
    if (taskSuggestions.length > 0) {
      const { error: taskInsertError } = await supabase.from("tasks").insert(
        taskSuggestions.map((t) => ({
          workspace_id: body.tasksWorkspaceId,
          chat_id: body.chatId,
          title: t.title,
          generated_by_ai: true,
        })),
      );
      if (taskInsertError) {
        console.error("ai-chat: errore insert tasks", taskInsertError);
        taskInsertFailed = true;
      }
    }

    // A differenza di transazioni/promemoria/attività, remember_fact non è mai
    // condizionato a un Workspace (sempre disponibile, vedi buildSystemPrompt) — quindi
    // nessun "*ToolEnabled" da controllare qui, solo l'esito dell'estrazione.
    const memorySuggestions = extractMemorySuggestions(anthropicBody)
      .map(sanitizeMemory)
      .filter((m): m is MemorySuggestion => m !== null);

    let memoryInsertFailed = false;
    if (memorySuggestions.length > 0) {
      if (!currentUserId) {
        // Non dovrebbe capitare (l'Authorization header è verificato all'ingresso), ma
        // senza un user_id non c'è un owner valido da scrivere: meglio segnalarlo che
        // violare silenziosamente memories_owner_matches_level.
        console.error(
          "ai-chat: remember_fact senza currentUserId, insert saltato",
        );
        memoryInsertFailed = true;
      } else {
        const { error: memoryInsertError } = await supabase.from("memories")
          .insert(
            memorySuggestions.map((m) => ({
              content: m.content,
              level: "global",
              origin: "ai",
              user_id: currentUserId,
            })),
          );
        if (memoryInsertError) {
          console.error("ai-chat: errore insert memories", memoryInsertError);
          memoryInsertFailed = true;
        }
      }
    }

    // Il testo finale non deve mai affermare un successo che non c'è stato: se
    // l'insert di transazioni/promemoria/elementi di lista/memorie fallisce, lo
    // diciamo esplicitamente invece di lasciare che la risposta del modello (scritta
    // prima di sapere se l'insert sarebbe riuscito) suggerisca il contrario. Elenco
    // generico (non frasi cucite per ogni combinazione): con quattro categorie le
    // combinazioni possibili sono 15, non 3.
    const failedInserts: string[] = [];
    if (transactionInsertFailed) failedInserts.push("le transazioni");
    if (recurringTransactionInsertFailed) {
      failedInserts.push("la spesa/entrata ricorrente");
    }
    if (reminderInsertFailed) failedInserts.push("i promemoria");
    if (taskInsertFailed) failedInserts.push("gli elementi della lista");
    if (memoryInsertFailed) failedInserts.push("le informazioni da ricordare");

    let finalReplyText = replyText;
    if (failedInserts.length > 0) {
      finalReplyText =
        `Non sono riuscito a salvare: ${failedInserts.join(", ")}. Riprova.` +
        (replyText ? `\n\n${replyText}` : "");
    } else if (!finalReplyText && suggestions.length > 0) {
      finalReplyText = `Ho registrato ${suggestions.length} ${
        suggestions.length === 1 ? "transazione" : "transazioni"
      } in attesa di conferma nella sezione Bilancio.`;
    } else if (!finalReplyText && recurringTransactionSuggestions.length > 0) {
      const frequencyLabel = recurringTransactionSuggestions[0].frequency === "weekly"
        ? "ogni settimana"
        : "ogni mese";
      finalReplyText =
        `Ho registrato la spesa/entrata ricorrente (${frequencyLabel}): comparirà "in ` +
        "attesa di conferma" +
        `" nella sezione Bilancio ad ogni scadenza.`;
    } else if (!finalReplyText && reminderRows.length > 0) {
      // "Promemoria" è invariante in italiano: nessuna forma plurale distinta da gestire.
      // reminderRows conta le occorrenze reali (una ricorrenza ne genera più di una),
      // non i suggerimenti logici del modello.
      const hasRecurrence = reminderSuggestions.some((r) =>
        r.recurrence !== null
      );
      finalReplyText = hasRecurrence
        ? `Ho creato un promemoria ricorrente (${reminderRows.length} occorrenze) ` +
          "nella sezione Appuntamenti."
        : `Ho creato ${reminderRows.length} promemoria nella sezione Appuntamenti.`;
    } else if (!finalReplyText && taskSuggestions.length > 0) {
      finalReplyText = `Ho aggiunto ${taskSuggestions.length} ${
        taskSuggestions.length === 1 ? "elemento" : "elementi"
      } alla lista nella sezione Attività.`;
    } else if (!finalReplyText && memorySuggestions.length > 0) {
      finalReplyText = memorySuggestions.length === 1
        ? "Ho memorizzato questa informazione."
        : `Ho memorizzato ${memorySuggestions.length} informazioni.`;
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
      // Se l'insert delle transazioni è fallito, non c'è nulla da confermare inline:
      // la Chat mostra Conferma/Scarta solo per transazioni davvero salvate.
      pending_transaction_ids: transactionInsertFailed
        ? []
        : insertedTransactionIds,
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
  remindersWorkspaceId: string | null,
  tasksWorkspaceId: string | null,
): Promise<
  {
    systemPrompt: string;
    sourceReferences: string[];
    transactionToolEnabled: boolean;
    reminderToolEnabled: boolean;
    taskToolEnabled: boolean;
  }
> {
  // Verificato indipendentemente da `workspaceId` (la sezione Bilancio): un
  // promemoria va sempre nella sezione Appuntamenti, un Workspace diverso. Solo
  // un controllo di esistenza/accesso (RLS) — a differenza del Workspace attivo,
  // non ne serve il contenuto (Note/Task/Documenti) per il contesto della Chat.
  const reminderToolEnabled = remindersWorkspaceId
    ? Boolean(
      (await supabase
        .from("workspaces")
        .select("id")
        .eq("id", remindersWorkspaceId)
        .maybeSingle()).data,
    )
    : false;

  // Stesso ragionamento di reminderToolEnabled, per la sezione Attività (Liste/
  // checklist via Chat).
  const taskToolEnabled = tasksWorkspaceId
    ? Boolean(
      (await supabase
        .from("workspaces")
        .select("id")
        .eq("id", tasksWorkspaceId)
        .maybeSingle()).data,
    )
    : false;

  // query_balance_summary/query_reminders/remember_fact sono sempre disponibili (Fase
  // 3, "Chat come Home" — richiesta esplicita dell'utente: "qualsiasi domanda che
  // riguardi le informazioni al suo interno"): a differenza di extract_transactions/
  // create_reminder/manage_tasks, non dipendono da un Workspace attivo — leggono/
  // scrivono sotto RLS solo i dati del chiamante, ovunque si trovi la conversazione.
  const today = new Date().toISOString().slice(0, 10);
  let alwaysOnInstructions =
    `${QUERY_TOOL_INSTRUCTIONS}\n\n${REMEMBER_FACT_TOOL_INSTRUCTIONS}`;
  if (reminderToolEnabled) {
    alwaysOnInstructions = `${alwaysOnInstructions}\n\n${REMINDER_TOOL_INSTRUCTIONS}`;
  }
  if (taskToolEnabled) {
    alwaysOnInstructions = `${alwaysOnInstructions}\n\n${TASK_TOOL_INSTRUCTIONS}`;
  }

  // Memorie globali dell'utente (Domain Model, entità Memory — prima slice minima):
  // iniettate nel contesto indipendentemente dal Workspace attivo, così l'AI può
  // davvero usarle nelle risposte, non solo salvarle (altrimenti la feature sarebbe
  // "sola scrittura").
  const { data: memoryRows } = await supabase
    .from("memories")
    .select("content")
    .eq("level", "global")
    .order("updated_at", { ascending: false })
    .limit(MAX_MEMORY_ITEMS);
  const memoryItems: string[] = (memoryRows ?? []).map(
    (m: { content: string }) => `- ${m.content}`,
  );
  const memoriesSection = memoryItems.length > 0
    ? `Cose da ricordare su questo utente:\n${memoryItems.join("\n")}`
    : null;

  if (!workspaceId) {
    // Una Chat senza Workspace non ha dove collegare una transazione: niente strumento.
    return {
      systemPrompt: `${ASSISTANT_PERSONA}\n\n${alwaysOnInstructions}\n\nData odierna: ${today}.${
        memoriesSection ? `\n\n${memoriesSection}` : ""
      }`,
      sourceReferences: [],
      transactionToolEnabled: false,
      reminderToolEnabled,
      taskToolEnabled,
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
      systemPrompt: `${ASSISTANT_PERSONA}\n\n${alwaysOnInstructions}\n\nData odierna: ${today}.${
        memoriesSection ? `\n\n${memoriesSection}` : ""
      }`,
      sourceReferences: [],
      transactionToolEnabled: false,
      reminderToolEnabled,
      taskToolEnabled,
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
        .select("id, name, chat_id")
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
  // `chat_id` (Knowledge Graph "lite" — richiesta esplicita dell'utente): un
  // Documento allegato durante una conversazione lo dice esplicitamente nel
  // contesto, coerente con docs/product/13-prompt-engineering.md
  // ("propone collegamenti con altri contenuti del Workspace").
  const documentItems: ContextItem[] = (documents ?? []).map(
    (d: { id: string; name: string; chat_id: string | null }) => ({
      id: d.id,
      label: `- ${d.name}${d.chat_id ? " (allegato in una conversazione)" : ""}`,
    }),
  );

  // "Data odierna" (calcolata in testa alla function) dà al modello un riferimento
  // affidabile per risolvere date relative ("questo mese", "il mese scorso").
  const sections: string[] = [
    `Data odierna: ${today}.`,
  ];
  if (memoriesSection) sections.push(memoriesSection);
  sections.push(
    `Workspace attivo: "${workspace.name}"${
      workspace.description ? ` — ${workspace.description}` : ""
    }`,
  );
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

  const toolInstructions =
    `${TRANSACTION_TOOL_INSTRUCTIONS}\n\n${RECURRING_TRANSACTION_TOOL_INSTRUCTIONS}` +
    `\n\n${alwaysOnInstructions}`;
  const systemPrompt =
    `${ASSISTANT_PERSONA}\n\n${toolInstructions}\n\n${sections.join("\n\n")}`;
  const sourceReferences = [...noteItems, ...taskItems, ...documentItems].map((
    i,
  ) => i.id);

  return {
    systemPrompt,
    sourceReferences,
    transactionToolEnabled: true,
    reminderToolEnabled,
    taskToolEnabled,
  };
}

// Costruisce i messaggi nel formato Anthropic. Solo l'ultimo messaggio
// dell'utente può portare immagini (non l'intera cronologia, per contenere
// costo/latenza): per quella riga, se ha `attachment_ids`, il content
// diventa un array di blocchi testo+immagini invece di una semplice stringa.
async function buildAnthropicMessages(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  // deno-lint-ignore no-explicit-any
  historyRows: any[],
): Promise<{ role: string; content: string | AnthropicContentBlock[] }[]> {
  const rows = historyRows.filter((row) =>
    row.role === "user" || row.role === "ai"
  );

  let lastUserRowIndex = -1;
  for (let i = rows.length - 1; i >= 0; i--) {
    if (rows[i].role === "user") {
      lastUserRowIndex = i;
      break;
    }
  }

  return await Promise.all(
    rows.map(async (row, index) => {
      const role = row.role === "ai" ? "assistant" : "user";
      const attachmentIds: string[] = Array.isArray(row.attachment_ids)
        ? row.attachment_ids
        : [];

      if (index !== lastUserRowIndex || attachmentIds.length === 0) {
        return { role, content: row.content as string };
      }

      const blocks: AnthropicContentBlock[] = [
        { type: "text", text: row.content as string },
      ];
      for (const documentId of attachmentIds.slice(0, MAX_IMAGE_ATTACHMENTS)) {
        const imageBlock = await fetchImageBlock(supabase, documentId);
        if (imageBlock) blocks.push(imageBlock);
      }
      return { role, content: blocks };
    }),
  );
}

// Scarica un allegato (righe `documents`, bucket Storage `documents` — stesso
// bucket/tabella usati da apps/mobile per la sezione Documenti, riusati qui
// per gli allegati di Chat) e lo converte in un blocco immagine Anthropic.
// Nessun privilegio aggiuntivo: stesso client autenticato col JWT del
// chiamante usato per il resto della function — le stesse RLS/policy Storage
// già verificate per la sezione Documenti si applicano identiche qui.
// Ritorna `null` (silenziosamente, non un errore che blocca il turno) se il
// documento non è leggibile o l'immagine supera MAX_IMAGE_BYTES.
async function fetchImageBlock(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  documentId: string,
): Promise<AnthropicImageBlock | null> {
  const { data: document } = await supabase
    .from("documents")
    .select("storage_path, mime_type")
    .eq("id", documentId)
    .maybeSingle();
  if (!document) return null;

  const { data: blob, error } = await supabase.storage
    .from("documents")
    .download(document.storage_path);
  if (error || !blob) return null;

  const bytes = new Uint8Array(await blob.arrayBuffer());
  if (bytes.byteLength > MAX_IMAGE_BYTES) return null;

  return {
    type: "image",
    source: {
      type: "base64",
      media_type: document.mime_type,
      data: encodeBase64(bytes),
    },
  };
}

// Lettura isolata di uno scontrino/ricevuta già caricato (Fase 3, "OCR sugli scontrini
// allegati manualmente" — integrazione richiesta esplicitamente): nessuna riga `messages`
// creata, un solo giro con Anthropic e tool_choice forzato su extract_transactions (non
// "auto" come nel resto della Chat) perché qui serve sempre un risultato strutturato da
// precompilare nel form di apps/mobile, mai una risposta in prosa. Non bloccante per il
// chiamante: qualunque esito diverso da "estratto con successo" (documento non
// leggibile, Anthropic non disponibile, nessuna transazione valida nella risposta) torna
// `{ ok: true, result: null }`, mai un errore — il form resta semplicemente vuoto, come
// se l'utente non avesse allegato nulla.
async function handleExtractReceipt(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  anthropicApiKey: string,
  documentId: string,
): Promise<Response> {
  const imageBlock = await fetchImageBlock(supabase, documentId);
  if (!imageBlock) return jsonReceiptResult(null);

  const today = new Date().toISOString().slice(0, 10);
  const anthropicResponse = await fetch(ANTHROPIC_API_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": anthropicApiKey,
      "anthropic-version": ANTHROPIC_VERSION,
    },
    body: JSON.stringify({
      model: RECEIPT_EXTRACTION_MODEL,
      max_tokens: MAX_OUTPUT_TOKENS,
      thinking: { type: "disabled" },
      system: `${RECEIPT_EXTRACTION_SYSTEM_PROMPT}\n\nData odierna: ${today}.`,
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: "Estrai i dati di questo scontrino/ricevuta." },
            imageBlock,
          ],
        },
      ],
      tools: [EXTRACT_TRANSACTIONS_TOOL],
      tool_choice: { type: "tool", name: "extract_transactions" },
    }),
  });

  if (!anthropicResponse.ok) {
    const detail = await anthropicResponse.text();
    console.error(
      "ai-chat: errore Anthropic (extract-receipt)",
      anthropicResponse.status,
      detail,
    );
    return jsonReceiptResult(null);
  }

  const anthropicBody = await anthropicResponse.json();
  const rawSuggestions = extractTransactionSuggestions(anthropicBody);
  const sanitized = rawSuggestions
    .map(sanitizeTransaction)
    .find((t): t is TransactionSuggestion => t !== null) ?? null;
  return jsonReceiptResult(sanitized);
}

function jsonReceiptResult(result: TransactionSuggestion | null): Response {
  return new Response(JSON.stringify({ ok: true, result }), {
    status: 200,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

const BASE64_CHARS =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

// Codifica base64 scritta a mano, nessuna dipendenza esterna: evita lo stesso
// problema già incontrato in questa sessione con `jsr:` irraggiungibile nella
// rete di verifica del sandbox (funzionerebbe nel runtime reale di Supabase,
// ma qui non è verificabile — meglio non dipenderne affatto).
function encodeBase64(bytes: Uint8Array): string {
  let result = "";
  let i = 0;
  for (; i + 3 <= bytes.length; i += 3) {
    const chunk = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
    result += BASE64_CHARS[(chunk >> 18) & 0x3f];
    result += BASE64_CHARS[(chunk >> 12) & 0x3f];
    result += BASE64_CHARS[(chunk >> 6) & 0x3f];
    result += BASE64_CHARS[chunk & 0x3f];
  }
  const remaining = bytes.length - i;
  if (remaining === 1) {
    const chunk = bytes[i] << 16;
    result += BASE64_CHARS[(chunk >> 18) & 0x3f];
    result += BASE64_CHARS[(chunk >> 12) & 0x3f];
    result += "==";
  } else if (remaining === 2) {
    const chunk = (bytes[i] << 16) | (bytes[i + 1] << 8);
    result += BASE64_CHARS[(chunk >> 18) & 0x3f];
    result += BASE64_CHARS[(chunk >> 12) & 0x3f];
    result += BASE64_CHARS[(chunk >> 6) & 0x3f];
    result += "=";
  }
  return result;
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

// Tutti i blocchi tool_use di un turno, di qualunque strumento — a differenza di
// extractTransactionSuggestions/extractReminderSuggestions (filtrati per un nome
// specifico), serve qui per costruire un tool_result per OGNI tool_use quando si fa un
// secondo giro con Anthropic (vedi il ramo `queryToolUseBlocks.length > 0` più sopra):
// l'API rifiuta la richiesta se anche un solo tool_use resta senza risposta.
// deno-lint-ignore no-explicit-any
function extractToolUseBlocks(
  anthropicBody: any,
): { id: string; name: string; input: unknown }[] {
  const blocks = anthropicBody?.content;
  if (!Array.isArray(blocks)) return [];
  return blocks
    .filter((block: { type: string }) => block.type === "tool_use")
    .map((block: { id: string; name: string; input: unknown }) => ({
      id: block.id,
      name: block.name,
      input: block.input,
    }));
}

interface BalanceSummaryResult {
  periodStart: string;
  periodEnd: string;
  incomeCents: number;
  expenseCents: number;
  balanceCents: number;
  byCategory: { category: string; expenseCents: number }[];
  transactionCount: number;
}

// Categoria dei Bilanci condivisi (packages/domain/lib/src/shared_balance_category.dart):
// duplicata qui perché questo progetto non condivide tipi tra Dart e TypeScript (stesso
// principio già applicato a TRANSACTION_CATEGORIES) — se cambia va cambiata in entrambi i
// posti.
const SHARED_BALANCE_CATEGORY = "bilancio_condiviso";

// Esegue query_balance_summary sotto RLS (stesso client con JWT del chiamante usato per
// tutta la function: nessun privilegio aggiuntivo). Esclude sempre i Bilanci condivisi —
// stessa esclusione già applicata lato client in BalanceOverviewScreen (Fase 3, "Bilancio
// condiviso": due Bilanci separati, non un unico totale che li confonda) — replicata qui
// perché questa function non ha altro modo di saperlo.
async function queryBalanceSummary(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  rawInput: unknown,
): Promise<BalanceSummaryResult | { error: string }> {
  const input = (typeof rawInput === "object" && rawInput !== null)
    ? rawInput as Record<string, unknown>
    : {};
  const periodStart = typeof input.period_start === "string"
    ? input.period_start
    : "";
  const periodEnd = typeof input.period_end === "string"
    ? input.period_end
    : "";
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(periodStart) ||
    !/^\d{4}-\d{2}-\d{2}$/.test(periodEnd)
  ) {
    return { error: "Periodo non valido." };
  }

  const { data: workspaces, error: workspacesError } = await supabase
    .from("workspaces")
    .select("id, category");
  if (workspacesError) {
    console.error(
      "ai-chat: errore query_balance_summary (workspaces)",
      workspacesError,
    );
    return { error: "Non è stato possibile leggere i Workspace." };
  }

  const personalWorkspaceIds = (workspaces ?? [])
    .filter((w: { category: string | null }) =>
      w.category !== SHARED_BALANCE_CATEGORY
    )
    .map((w: { id: string }) => w.id);

  if (personalWorkspaceIds.length === 0) {
    return {
      periodStart,
      periodEnd,
      incomeCents: 0,
      expenseCents: 0,
      balanceCents: 0,
      byCategory: [],
      transactionCount: 0,
    };
  }

  const { data: transactions, error: transactionsError } = await supabase
    .from("transactions")
    .select("type, amount_cents, category")
    .in("workspace_id", personalWorkspaceIds)
    .eq("status", "confirmed")
    .gte("occurred_at", periodStart)
    .lte("occurred_at", periodEnd);

  if (transactionsError) {
    console.error(
      "ai-chat: errore query_balance_summary (transactions)",
      transactionsError,
    );
    return { error: "Non è stato possibile leggere le transazioni." };
  }

  let incomeCents = 0;
  let expenseCents = 0;
  const byCategoryMap = new Map<string, number>();
  for (
    const t of (transactions ??
      []) as { type: string; amount_cents: number; category: string | null }[]
  ) {
    const amount = Number(t.amount_cents) || 0;
    if (t.type === "income") {
      incomeCents += amount;
    } else {
      expenseCents += amount;
      const key = t.category ?? "altro";
      byCategoryMap.set(key, (byCategoryMap.get(key) ?? 0) + amount);
    }
  }

  return {
    periodStart,
    periodEnd,
    incomeCents,
    expenseCents,
    balanceCents: incomeCents - expenseCents,
    byCategory: [...byCategoryMap.entries()].map((
      [category, categoryExpenseCents],
    ) => ({ category, expenseCents: categoryExpenseCents })),
    transactionCount: (transactions ?? []).length,
  };
}

interface ReminderQueryResult {
  periodStart: string;
  periodEnd: string;
  events: { title: string; startsAt: string }[];
}

// Esegue query_reminders sotto RLS: a differenza delle transazioni, i promemoria non
// hanno un concetto di condivisione (RLS owner-only, vedi calendar_events), quindi nessun
// filtro aggiuntivo da applicare qui oltre al periodo.
async function queryReminders(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  rawInput: unknown,
): Promise<ReminderQueryResult | { error: string }> {
  const input = (typeof rawInput === "object" && rawInput !== null)
    ? rawInput as Record<string, unknown>
    : {};
  const periodStart = typeof input.period_start === "string"
    ? input.period_start
    : "";
  const periodEnd = typeof input.period_end === "string" ? input.period_end : "";
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(periodStart) ||
    !/^\d{4}-\d{2}-\d{2}$/.test(periodEnd)
  ) {
    return { error: "Periodo non valido." };
  }

  const { data: events, error } = await supabase
    .from("calendar_events")
    .select("title, starts_at")
    .is("deleted_at", null)
    .gte("starts_at", `${periodStart}T00:00:00`)
    .lte("starts_at", `${periodEnd}T23:59:59`)
    .order("starts_at", { ascending: true });

  if (error) {
    console.error("ai-chat: errore query_reminders", error);
    return { error: "Non è stato possibile leggere i promemoria." };
  }

  return {
    periodStart,
    periodEnd,
    events: (events ?? []).map((e: { title: string; starts_at: string }) => ({
      title: e.title,
      startsAt: e.starts_at,
    })),
  };
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
  // A differenza di type/description/amount_cents/occurred_at, una categoria mancante o non
  // riconosciuta non invalida la transazione: ricade su "altro" (stesso default della colonna
  // DB e di Transaction.category lato Dart), non blocca la registrazione di una spesa reale.
  const category = TRANSACTION_CATEGORIES.includes(r.category as TransactionCategory)
    ? (r.category as TransactionCategory)
    : "altro";
  if (!type) return null;
  if (!description) return null;
  if (!Number.isFinite(amountCents) || amountCents <= 0) return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(occurredAt)) return null;
  return { type, description, amountCents, occurredAt, category };
}

// Estrae le chiamate allo strumento create_recurring_transaction — stesso pattern di
// extractTransactionSuggestions (tool_choice "auto", un blocco tool_use per modello).
// deno-lint-ignore no-explicit-any
function extractRecurringTransactionSuggestions(anthropicBody: any): unknown[] {
  const blocks = anthropicBody?.content;
  if (!Array.isArray(blocks)) return [];
  return blocks
    .filter((block: { type: string; name?: string }) =>
      block.type === "tool_use" && block.name === "create_recurring_transaction"
    )
    // deno-lint-ignore no-explicit-any
    .map((block: any) => block.input);
}

// Validazione difensiva, stesso principio di sanitizeTransaction.
function sanitizeRecurringTransaction(
  raw: unknown,
): RecurringTransactionSuggestion | null {
  if (typeof raw !== "object" || raw === null) return null;
  const r = raw as Record<string, unknown>;
  const type = r.type === "income" || r.type === "expense" ? r.type : null;
  const description = typeof r.description === "string"
    ? r.description.trim()
    : "";
  const amountCents = Math.round(Number(r.amount_cents));
  const frequency = r.frequency === "weekly" || r.frequency === "monthly"
    ? r.frequency
    : null;
  const firstOccurrenceAt = typeof r.first_occurrence_at === "string"
    ? r.first_occurrence_at
    : "";
  const category = TRANSACTION_CATEGORIES.includes(r.category as TransactionCategory)
    ? (r.category as TransactionCategory)
    : "altro";
  if (!type) return null;
  if (!description) return null;
  if (!Number.isFinite(amountCents) || amountCents <= 0) return null;
  if (!frequency) return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(firstOccurrenceAt)) return null;
  return { type, description, amountCents, category, frequency, firstOccurrenceAt };
}

// Avanza una data (formato YYYY-MM-DD) di un periodo — duplicato di
// advanceOccurrence in create-due-recurring-transactions/index.ts: le Edge Function di
// questo progetto sono deployate indipendentemente, nessun modulo condiviso tra loro
// (stesso principio già applicato a TRANSACTION_CATEGORIES, duplicata invece di importata).
// `anchorDay` è il giorno "vero" della ricorrenza, fissato alla creazione — mai derivato da
// `dateIso` (vedi lo stesso commento nell'altra function per il bug che questo evita).
function advanceRecurringOccurrence(
  dateIso: string,
  frequency: TransactionRecurrenceFrequency,
  anchorDay: number,
): string {
  const date = new Date(`${dateIso}T00:00:00Z`);

  if (frequency === "weekly") {
    date.setUTCDate(date.getUTCDate() + 7);
    return date.toISOString().slice(0, 10);
  }

  const firstOfNextMonth = new Date(date);
  firstOfNextMonth.setUTCDate(1);
  firstOfNextMonth.setUTCMonth(firstOfNextMonth.getUTCMonth() + 1);
  const daysInNextMonth = new Date(
    Date.UTC(
      firstOfNextMonth.getUTCFullYear(),
      firstOfNextMonth.getUTCMonth() + 1,
      0,
    ),
  ).getUTCDate();
  firstOfNextMonth.setUTCDate(Math.min(anchorDay, daysInNextMonth));
  return firstOfNextMonth.toISOString().slice(0, 10);
}

// Estrae le chiamate allo strumento create_reminder dalla risposta Anthropic — stesso
// pattern di extractTransactionSuggestions (tool_choice "auto": il modello decide se
// usarlo, e può comparire insieme a extract_transactions nello stesso turno).
// deno-lint-ignore no-explicit-any
function extractReminderSuggestions(anthropicBody: any): unknown[] {
  const blocks = anthropicBody?.content;
  if (!Array.isArray(blocks)) return [];
  return blocks
    .filter((block: { type: string; name?: string }) =>
      block.type === "tool_use" && block.name === "create_reminder"
    )
    // deno-lint-ignore no-explicit-any
    .map((block: any) => block.input);
}

// Validazione difensiva, stesso principio di sanitizeTransaction: lo schema del tool
// vincola la forma del JSON, non la sua correttezza (una data non parsabile va
// scartata qui, non solo delegata al tipo di colonna `timestamptz` del DB).
function sanitizeReminder(raw: unknown): ReminderSuggestion | null {
  if (typeof raw !== "object" || raw === null) return null;
  const r = raw as Record<string, unknown>;
  const title = typeof r.title === "string" ? r.title.trim() : "";
  const startsAt = typeof r.starts_at === "string" ? r.starts_at : "";
  const startsAtDate = new Date(startsAt);
  const reminderMinutesBeforeRaw = r.reminder_minutes_before;
  const reminderMinutesBefore =
    reminderMinutesBeforeRaw === undefined || reminderMinutesBeforeRaw === null
      ? null
      : Math.round(Number(reminderMinutesBeforeRaw));
  // Un valore diverso da "none"/daily/weekly/monthly (es. il modello non lo valorizza
  // affatto) ricade su "nessuna ricorrenza", non blocca la registrazione del promemoria.
  const recurrence = r.recurrence === "daily" ||
      r.recurrence === "weekly" || r.recurrence === "monthly"
    ? r.recurrence
    : null;

  if (!title) return null;
  if (!startsAt || Number.isNaN(startsAtDate.getTime())) return null;
  if (
    reminderMinutesBefore !== null &&
    (!Number.isFinite(reminderMinutesBefore) || reminderMinutesBefore < 0)
  ) {
    return null;
  }
  return {
    title,
    startsAt: startsAtDate.toISOString(),
    reminderMinutesBefore,
    recurrence,
  };
}

// Espande un promemoria ricorrente nelle sue occorrenze (richiesta esplicita
// dell'utente: "promemoria ricorrenti") — una riga per occorrenza, non un'unica riga
// con una regola di ripetizione: send-due-reminders (già configurata, non toccata da
// questa slice) continua a leggere calendar_events come eventi indipendenti, ciascuno
// col proprio starts_at/notified_at.
function expandOccurrences(startsAt: Date, frequency: RecurrenceFrequency): Date[] {
  const count = RECURRENCE_OCCURRENCES[frequency];
  const occurrences: Date[] = [];

  if (frequency === "daily" || frequency === "weekly") {
    const stepDays = frequency === "daily" ? 1 : 7;
    for (let i = 0; i < count; i++) {
      const next = new Date(startsAt);
      next.setUTCDate(next.getUTCDate() + i * stepDays);
      occurrences.push(next);
    }
    return occurrences;
  }

  // "monthly": `setUTCMonth` da solo trabocca sui mesi più corti (es. il 31
  // gennaio + 1 mese diventa il 3 marzo, non il 28 febbraio) — bug verificato
  // manualmente prima di questa correzione. Si passa sempre dal giorno 1 del
  // mese di destinazione, poi si sceglie il giorno più vicino a quello
  // originale senza superare i giorni disponibili in quel mese.
  const originalDay = startsAt.getUTCDate();
  for (let i = 0; i < count; i++) {
    const firstOfTargetMonth = new Date(startsAt);
    firstOfTargetMonth.setUTCDate(1);
    firstOfTargetMonth.setUTCMonth(firstOfTargetMonth.getUTCMonth() + i);
    const daysInTargetMonth = new Date(
      Date.UTC(
        firstOfTargetMonth.getUTCFullYear(),
        firstOfTargetMonth.getUTCMonth() + 1,
        0,
      ),
    ).getUTCDate();
    const next = new Date(firstOfTargetMonth);
    next.setUTCDate(Math.min(originalDay, daysInTargetMonth));
    occurrences.push(next);
  }
  return occurrences;
}

// Estrae le chiamate allo strumento manage_tasks dalla risposta Anthropic — stesso
// pattern di extractReminderSuggestions, ma un singolo tool_use può contenere più
// elementi (`items`, un array), non uno solo: appiattiti in una lista di oggetti
// { title } per riusare la stessa forma di sanitizzazione per elemento.
// deno-lint-ignore no-explicit-any
function extractTaskSuggestions(anthropicBody: any): unknown[] {
  const blocks = anthropicBody?.content;
  if (!Array.isArray(blocks)) return [];
  return blocks
    .filter((block: { type: string; name?: string }) =>
      block.type === "tool_use" && block.name === "manage_tasks"
    )
    // deno-lint-ignore no-explicit-any
    .flatMap((block: any) =>
      Array.isArray(block.input?.items)
        ? block.input.items.map((item: unknown) => ({ title: item }))
        : []
    );
}

// Validazione difensiva, stesso principio di sanitizeReminder: un elemento non
// stringa o vuoto (dopo trim) va scartato qui, non solo delegato al check
// constraint `tasks_title_not_blank` del DB.
function sanitizeTask(raw: unknown): TaskSuggestion | null {
  if (typeof raw !== "object" || raw === null) return null;
  const r = raw as Record<string, unknown>;
  const title = typeof r.title === "string" ? r.title.trim() : "";
  if (!title) return null;
  return { title };
}

// Estrae le chiamate allo strumento remember_fact dalla risposta Anthropic — stesso
// pattern di extractReminderSuggestions (un blocco tool_use per fatto da ricordare).
// deno-lint-ignore no-explicit-any
function extractMemorySuggestions(anthropicBody: any): unknown[] {
  const blocks = anthropicBody?.content;
  if (!Array.isArray(blocks)) return [];
  return blocks
    .filter((block: { type: string; name?: string }) =>
      block.type === "tool_use" && block.name === "remember_fact"
    )
    // deno-lint-ignore no-explicit-any
    .map((block: any) => block.input);
}

// Validazione difensiva, stesso principio di sanitizeTask: un contenuto non stringa o
// vuoto (dopo trim) va scartato qui, non solo delegato al check constraint
// `memories_content_not_blank` del DB.
function sanitizeMemory(raw: unknown): MemorySuggestion | null {
  if (typeof raw !== "object" || raw === null) return null;
  const r = raw as Record<string, unknown>;
  const content = typeof r.content === "string" ? r.content.trim() : "";
  if (!content) return null;
  return { content };
}

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}
