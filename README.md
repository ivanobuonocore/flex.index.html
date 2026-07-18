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

Fase attuale: **Fase 1 — Foundation**, in corso (vedi `docs/product/26-execution-blueprint.md`).

Completato: repository monorepo, modello di dominio (`packages/domain`), Design System
(`packages/design-system`), autenticazione e navigazione principale su Supabase con Row Level
Security (`apps/mobile`, `infrastructure/supabase`), CI (lint, format, test).

Vedi `apps/mobile/README.md` per lo stato feature-per-feature e le istruzioni di setup locale.

## Stack tecnico

- Frontend: Flutter (Riverpod, GoRouter, architettura Feature First)
- Backend: Supabase (Postgres, Auth, Edge Functions, Storage, Realtime)
- AI: Claude API via AI Engine dedicato
