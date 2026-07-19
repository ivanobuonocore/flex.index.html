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
richiederebbero un servizio di trascrizione aggiuntivo non ancora attivato. I promemoria con
notifiche push restano sospesi in attesa di trasformare l'app in una PWA installabile (richiede
una pianificazione a sé).

Memoria resta nelle prossime slice.

Vedi `apps/mobile/README.md` per lo stato feature-per-feature e le istruzioni di setup locale.

## Stack tecnico

- Frontend: Flutter (Riverpod, GoRouter, architettura Feature First)
- Backend: Supabase (Postgres, Auth, Edge Functions, Storage, Realtime)
- AI: Claude API via AI Engine dedicato
