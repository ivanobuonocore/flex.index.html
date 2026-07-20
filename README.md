# PIP — Personal Intelligence Platform

Assistente AI personale che unisce chat, gestione progetti, documenti, memoria e agenti AI specializzati in un'unica esperienza mobile-first (poi web/desktop).

## Documenti di riferimento

Leggi questi file, in quest'ordine, prima di contribuire:

1. [`AGENTS.md`](./AGENTS.md) — regole operative del repository (vincolanti)
2. [`PRODUCT_BIBLE.md`](./PRODUCT_BIBLE.md) — visione, mercato, UX, prodotto
3. [`ENGINEERING_HANDBOOK.md`](./ENGINEERING_HANDBOOK.md) — principi architetturali
4. [`CLAUDE.md`](./CLAUDE.md) — istruzioni operative per Claude Code

## Struttura del monorepo

```
pip/
├── apps/
│   ├── mobile/     # Flutter — app principale (MVP)
│   ├── web/        # Flutter web — fase successiva
│   └── admin/      # pannello di amministrazione — fase successiva
│
├── backend/
│   ├── api/            # API Gateway / servizi di dominio
│   ├── ai-engine/       # orchestrazione modelli, RAG, memoria, agenti
│   ├── workers/         # job asincroni (indicizzazione, sync, notifiche)
│   └── integrations/    # connettori verso servizi esterni
│
├── packages/
│   ├── ui/              # componenti UI condivisi
│   ├── design-system/   # token, temi, tipografia
│   ├── shared/           # utility condivise
│   ├── domain/            # modello di dominio (indipendente dal framework)
│   └── sdk/               # client per le API pubbliche
│
├── infrastructure/    # config deploy, IaC
├── docs/              # Product Bible, Engineering Handbook, ADR, API, DB, roadmap
└── scripts/           # script di sviluppo/CI
```

## Stato del progetto

Fase attuale: **Fase 3 — AI Layer**, in corso (vedi `docs/product/26-execution-blueprint.md`).

**Fase 1 — Foundation** (completata): repository monorepo, modello di dominio
(`packages/domain`), Design System (`packages/design-system`), autenticazione e navigazione
principale su Supabase con Row Level Security.

**Fase 2 (slice 1)**: Home del Workspace, Note e Task — CRUD completo, realtime, RLS verificata.

**Fase 2 (slice 2)**: Documenti — upload/apertura/eliminazione su Supabase Storage (bucket
privato, signed URL), RLS verificata (anche sulle policy di Storage, con uno schema fittizio in
assenza di Docker in questa sessione — dettagli in `docs/database/README.md`).

**Fase 2 (slice 3)**: Ricerca Universale — full-text search cross-tabella (Postgres, funzione
`security invoker`) su Workspace/Note/Task/Documenti, RLS verificata (nessun filtro esplicito
nella funzione: l'isolamento dipende dalle RLS delle tabelle sottostanti). Fase 2 completa.

**Fase 3 (slice 1)**: AI Engine + Chat contestuale al Workspace. L'AI Engine è una Supabase Edge
Function (`ai-chat`) — mai il frontend collegato direttamente ad Anthropic. Contesto costruito
per euristica (Workspace + Note/Task/Documenti recenti, non ricerca semantica), un solo agente
generico, nessuno streaming. Non verificata con una chiamata reale al provider (nessuna chiave
Anthropic disponibile in questa sessione): verificata staticamente (`deno check`/`lint`/`fmt`) e
con test applicativi su repository fake — dettagli in `docs/database/README.md` e
`apps/mobile/README.md`.

**Fase 3 (slice 2)**: Bilancio (entrate e uscite) — aggiunta oltre alla roadmap originale, su
richiesta diretta dell'utente, ispirata all'app Planito (assistente su WhatsApp con contabilità
in linguaggio naturale). L'AI Engine riconosce spese ed entrate descritte in linguaggio naturale
(es. "barbiere 23€, supermercato 35€" oppure "ho ricevuto lo stipendio di 1500€") tramite uno
strumento Anthropic dedicato (`extract_transactions`) e le registra come "in attesa di conferma":
contano nel saldo della schermata Bilancio solo dopo che l'utente le conferma esplicitamente (AI
Constitution, Principio 1 — "l'AI suggerisce, l'utente decide"). RLS verificata su Postgres
locale; Edge Function verificata solo staticamente, stessi limiti della slice precedente.

**Fase 3 (slice 3)**: Foto nei messaggi di Chat — continuazione della richiesta "rendi l'app
simile a Planito". Riusa la sezione Documenti esistente (nessuna nuova tabella/migrazione): una
foto allegata a un messaggio è un `Document` con `chat_id` valorizzato, referenziato in
`Message.attachmentIds`. L'Edge Function `ai-chat` invia l'immagine dell'ultimo messaggio a
Claude come contenuto visivo (max 3 foto, ~5MB ciascuna). I messaggi vocali restano fuori scope:
richiederebbero un servizio di trascrizione aggiuntivo non ancora attivato.

**Fase 3 (slice 4)**: Notifiche push vere — prima slice: infrastruttura + prova. Su richiesta
esplicita dell'utente (ha rifiutato l'alternativa "elenco promemoria solo in app" per volere
notifiche di sistema reali), l'app è ora anche una PWA installabile ("Aggiungi a Home" su iPhone)
con Web Push: tabella `push_subscriptions` (livello account), Edge Function `send-test-push`
(`npm:web-push`, mai l'AI Engine), service worker dedicato (`push-worker.js`), e una card
"Notifiche" in Profilo con attivazione e un pulsante di prova. Deliberatamente non ancora i
Promemoria veri (`CalendarEvent`, già modellato ma non implementato): questa slice prova solo che
l'intera catena browser↔notifica funziona, prima di costruirci sopra dei contenuti. Verificata
staticamente (RLS su Postgres locale, `deno check`/`lint`/`fmt`, `flutter analyze` e un vero
`flutter build web`); il recapito reale su un dispositivo non è verificabile da questo ambiente.

**Fase 3 (slice 5)**: Chat come Home dell'app — richiesta esplicita dell'utente ("la funzione
principale deve essere la chat"), dopo aver notato che nella versione precedente la Chat era
sepolta 3-4 tocchi dentro un Workspace. La tab "Oggi" viene rimossa: il suo contenuto (saluto,
Workspace recenti) confluisce nella nuova Home, che è ora `/chat` — la prima cosa che si vede
dopo il login, con tutte le conversazioni dell'utente e la creazione diretta di una nuova chat
(privata o in un Workspace). Da una Chat di Workspace, un pulsante "cartelle" apre
Note/Attività/Documenti/Bilancio senza uscire dalla conversazione. Nessun cambio al modello dati:
`Chat` resta collegata a un Workspace come prima (CLAUDE.md, "Chat è una feature dentro Workspace,
non un dominio a sé stante") — cambia solo la navigazione.

**Fase 3 (slice 6)**: Emoji nelle risposte AI + Bilancio globale (grafico a torta) — su richiesta
esplicita dell'utente ("vorrei che la chat fosse più bella... che rispondesse anche con emoji" e
"un grafico a torta... dove attualmente si trova 'ricerca', 'workspace'... con un prospetto di
entrate e di uscite"). Due modifiche indipendenti:
- L'assistente AI (`ai-chat`) ora usa emoji con naturalezza nelle risposte (aggiunta al system
  prompt `ASSISTANT_PERSONA`), non solo il selettore manuale già presente nell'input della Chat
  (restyling stile WhatsApp, stessa richiesta).
- Nuova quinta voce di navigazione **Bilancio**, tra Ricerca e Profilo: a differenza del Bilancio
  per Workspace (già esistente, raggiungibile dalle "cartelle" di una Chat), questa schermata
  aggrega le transazioni confermate di **tutti** i Workspace dell'utente in un grafico a torta
  entrate/uscite (`fl_chart`) più un prospetto testuale del saldo — le stesse transazioni che la
  Chat riconosce e registra in linguaggio naturale, indipendentemente da quale Workspace le ha
  generate. Richiede `TransactionRepository.watchTransactions(workspaceId)` → `(String?)`
  (`null` = tutti i Workspace, stesso pattern già usato da `ChatRepository.watchChats`).
  Nessuna nuova tabella o migrazione: solo un filtro applicativo in meno, con l'isolamento tra
  utenti sempre garantito dalle RLS di `transactions`.

**Fase 3 (slice 7A)**: Sezioni fisse — primo passo di un cambio più ampio richiesto esplicitamente
dall'utente ("non deve essere l'utente a gestire il workspace ma la chat... i workspace
predefiniti devono già comparire"). Ogni utente ha ora sempre 4 Workspace di sistema — Bilancio,
Appuntamenti, Attività, Documenti — creati automaticamente al primo accesso e sempre visibili
(striscia "Sezioni" in testa alla Home Chat, oltre che nella tab Workspace). Sono rinominabili ma
non eliminabili (strutturali); i Workspace liberi restano invece rinominabili **ed eliminabili** —
la `WorkspaceCard` guadagna un menu con entrambe le azioni. Questa slice pone le fondamenta (le
sezioni esistono, sono navigabili, mostrano un'anteprima viva riusando Bilancio/Attività/Documenti
già esistenti); le prossime slice collegheranno l'estrazione AI in Chat direttamente a queste
sezioni (categorizzazione delle spese, tool `create_calendar_event`/`manage_tasks`), unificheranno
la Chat in una sola conversazione, e rimuoveranno la sezione Note.

**Fase 3 (slice 7B)**: Chat unica — richiesta esplicita dell'utente ("la chat deve essere unica...
non deve fare più chat... la logica è gestire in unico posto tutte le attività"). Rimossa la
creazione di nuove chat e le chat per-Workspace: `/chat` è ora sia la Home sia l'unica
conversazione dell'utente, creata automaticamente al primo accesso (riusa quella più recente se
esistevano già chat da prima di questa slice — non ne crea mai una seconda). La striscia "Sezioni"
(slice 7A) resta sempre visibile in testa, sopra i messaggi. Le transazioni riconosciute in Chat
vanno sempre nella sezione Bilancio, le foto sempre in Documenti — instradate tramite gli id delle
sezioni fisse, non più tramite il Workspace "di quella chat" (che non esiste più come concetto).
Durante il lavoro, un test ha scoperto un overflow verticale preesistente in `WorkspaceCard`
quando un'anteprima viva è più lunga di una riga in una card stretta: corretto (`maxLines` +
`overflow: ellipsis` su nome e sottotitolo).

**Fase 3 (slice 7C)**: Bilancio con categorie — richiesta esplicita dell'utente: una spesa come
"barbiere" va classificata, non solo registrata. `TransactionCategory` (10 categorie fisse:
Alimentari/Trasporti/Casa/Bollette/Salute/Svago/Shopping/Istruzione/Stipendio/Altro, non
estensibile dall'utente) su ogni Transazione, con un picker nella creazione/modifica manuale e la
categoria visibile in ogni riga del Bilancio. L'Edge Function `ai-chat` ora classifica
automaticamente le transazioni che estrae dalla Chat (es. "barbiere" → Svago) — una
classificazione mancante o non riconosciuta ricade su "Altro" invece di far scartare l'intera
transazione, così un errore dell'AI sulla categoria non fa perdere una spesa reale.

**Redesign estetico**: richiesta esplicita dell'utente ("rendi più estetica l'interfaccia con
icone colorate e utilizzando un font dedicato... inserisci la Chat al centro... in un cerchio...
con i colori di Siri quando si attiva"). Font Manrope (via `google_fonts`) in tutta l'app; Bottom
Navigation riordinata con la Chat al centro in un cerchio dal gradiente ispirato al "glow" di Siri,
sollevato sopra la barra; icone colorate nelle voci di navigazione, nelle categorie di
Transazione, e nelle liste Note/Attività/Documenti. Durante il lavoro è stato scoperto e corretto
un rischio reale per l'affidabilità dei test: `google_fonts` scarica il font a runtime, il che
avrebbe reso ogni test che costruisce il tema dell'app dipendente dalla rete — ora i test lo
evitano rilevando l'esecuzione sotto `flutter test`.

**Nota operativa importante**: questa sessione non ha mai avuto un token di accesso al progetto
Supabase reale, quindi nessuna migrazione o Edge Function scritta in questo repository (in
nessuna slice) è mai stata applicata/deployata dall'assistente — serve eseguire manualmente `npx
supabase db push` e `npx supabase functions deploy` dopo ogni slice che tocca `infrastructure/
supabase/` (vedi `infrastructure/supabase/README.md`). Un ritardo in questo passaggio ha causato
un fallimento reale in produzione dopo la slice "Bilancio con categorie".

**Fix**: bug segnalato dall'utente ("ci sono più categorie di appuntamenti") — causato
esattamente dal gap operativo descritto sopra: senza l'indice unico di database (mai applicato),
il bootstrap delle sezioni fisse ha potuto inserire più righe con la stessa categoria a ogni
ricarica dell'app. Corretto su due livelli: la migrazione dell'indice ora disattiva prima le
righe duplicate esistenti (mantenendo la più vecchia), e `workspacesProvider` lato app filtra le
sezioni fisse duplicate allo stesso modo — così l'interfaccia è corretta anche subito, prima
ancora che tu applichi la migrazione.

**Fix Chat**: tre bug segnalati dall'utente in un'unica richiesta. (1) Emoji monocromatiche nella
demo web: causa il renderer CanvasKit (default su desktop), che non recupera i font emoji a
colori del sistema — build ora con `--web-renderer html` (limite noto di Flutter Web, non un bug
di questo progetto). (2) "Quando risponde non si blocca la pagina ma che esca di seguito senza
scatti, come whatsapp": la lista messaggi non scorreva mai automaticamente in fondo — corretto con
scroll automatico a ogni nuovo messaggio; la bolla "sta scrivendo" è ora l'ultimo elemento della
lista invece di un widget fisso sotto (quello causava lo "scatto" percepito quando appariva/
scompariva). (3) Il saluto in cima alla Chat ora capitalizza sempre il nome dell'utente. Colto
anche al volo: la striscia "Sezioni" è più sottile ed essenziale (56px, card compatta dedicata
invece della WorkspaceCard completa).

Memoria resta nelle prossime slice.

Vedi `apps/mobile/README.md` per lo stato feature-per-feature e le istruzioni di setup locale.

## Stack tecnico

- Frontend: Flutter (Riverpod, GoRouter, architettura Feature First)
- Backend: Supabase (Postgres, Auth, Edge Functions, Storage, Realtime)
- AI: Claude API via AI Engine dedicato
