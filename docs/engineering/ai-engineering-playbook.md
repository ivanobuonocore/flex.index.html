# AI Engineering Playbook — Capitolo 1: Repository e Architettura del Codice

## Obiettivo

Creare una codebase che rimanga ordinata anche dopo anni di sviluppo. Ogni sviluppatore deve capire
immediatamente dove aggiungere una nuova funzionalità.

## Monorepo

```
/
├── apps/            (mobile, web, admin)
├── backend/         (api, ai-engine, workers, integrations)
├── packages/        (ui, design-system, shared, domain, sdk)
├── infrastructure/
├── docs/
└── scripts/
```

## Frontend — Flutter, Feature First

```
features/
  workspace/ chat/ today/ search/ profile/ documents/ memory/ settings/ billing/
```

Ogni feature contiene: `presentation/ application/ domain/ data/` — riduce l'accoppiamento tra moduli.

> Nota: questa è la struttura *massima* disponibile, non obbligatoria per ogni feature — feature
> piccole (es. settings) non hanno bisogno di tutte e 4 le sottocartelle popolate fin da subito.

## State Management: Riverpod

Tipizzato, scalabile, testabile, indipendente dai widget, ottimo supporto code generation.

## Routing: GoRouter

Supporto Deep Link, Web, Universal Link, Navigation Guard.

## Backend — moduli

Authentication, Workspace, Conversation, AI, Memory, Search, Billing, Notification, Analytics. Ogni
modulo espone servizi e API ben definiti.

## AI Engine

Indipendente dal resto del backend. Responsabilità: selezione modello, costruzione contesto, gestione
prompt, esecuzione strumenti, orchestrazione agenti, streaming risposte.

## Convenzioni

Ogni file una sola responsabilità. Mai classi giganti. Funzioni brevi e leggibili. Dependency Injection sempre.

## Naming

Classi PascalCase · Variabili camelCase · Costanti SCREAMING_SNAKE_CASE · Endpoint kebab-case ·
Workspace ID UUID v7.

## Logging

Ogni richiesta genera un Trace ID. Ogni errore contiene: stack trace, utente, Workspace, modulo, timestamp.

## Error Handling

Mai mostrare errori tecnici all'utente. Messaggi chiari; dettagli nei log.

## Cache

Livelli: memoria → database locale → rete. La UI usa sempre il dato disponibile più rapido.

## Offline

Modifiche salvate localmente. Coda di sincronizzazione gestisce upload, retry, conflitti.

## Test — piramide

70% Unit · 20% Integration · 10% End-to-End. Ogni nuova funzionalità include test automatici.

> Nota: per un AI Engine con prompt/RAG/orchestrazione agenti, considerare una categoria a parte di
> "eval" (test di regressione sui prompt, valutazione qualità output) che non rientra bene né in unit
> né in integration test classici.

## CI/CD

Ogni Pull Request esegue: lint, format, test, analisi statica, build. Merge consentito solo se tutti i
controlli sono superati.

## Sicurezza

Mai chiavi API nel frontend. Secrets tramite vault e variabili d'ambiente. Autorizzazioni verificate sul backend.

## Performance — obiettivi iniziali

Apertura app < 2s · Primo streaming AI < 1s (quando possibile, da verificare presto con prototipo reale
dato che memoria+ricerca semantica aggiungono latenza) · Ricerca locale < 100ms · Navigazione tra
schermate < 150ms.

## Regola Finale

Il codice deve essere progettato per essere modificato facilmente. Una buona architettura non elimina il
cambiamento. Lo rende economico.
