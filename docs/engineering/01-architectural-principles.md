# Capitolo 1 – Architectural Principles

## Scopo

Definire i principi tecnici che guidano l'implementazione della piattaforma. Non descrive una tecnologia
specifica, ma stabilisce regole che consentano al sistema di evolvere senza perdere coerenza.

## Principio 1 – Il dominio viene prima del framework

Framework, librerie e servizi possono essere sostituiti. Il modello di dominio deve rimanere stabile. La
logica di business non dipende da Flutter, Supabase o da un particolare provider AI.

## Principio 2 – AI come servizio, non come dipendenza

Ogni chiamata passa attraverso un AI Engine interno che seleziona il modello più adatto, gestisce
fallback, controlla costi e limiti, normalizza le risposte. Il resto del sistema non comunica
direttamente con GPT, Claude o Gemini.

## Principio 3 – Workspace come dominio principale

Ogni risorsa (documenti, chat, task, memorie, timeline) appartiene a un Workspace. Il Workspace è il
confine logico del sistema.

## Principio 4 – Event Driven

Ogni evento importante genera un evento di dominio (es. `DocumentoCaricato`, `TaskCompletato`,
`WorkspaceCreato`, `MemoriaSalvata`, `KnowledgeGraphAggiornato`). Permettono di costruire notifiche,
automazioni e analisi senza accoppiare i componenti.

> ⚠️ Da decidere: naming degli eventi in italiano o inglese, per coerenza con le convenzioni di codice
> (PascalCase/camelCase in inglese definite nell'AI Engineering Playbook).

## Principio 5 – API First

Ogni funzionalità progettata come API prima di essere implementata nella UI. Frontend, app mobile e
future integrazioni condividono la stessa logica.

## Principio 6 – Offline First

Le operazioni principali continuano a funzionare con connettività limitata. Le modifiche si sincronizzano
appena disponibile la rete.

## Principio 7 – Modularità

Moduli indipendenti: Identity, Workspace, AI, Search, Memory, Knowledge Graph, Integrations, Billing,
Notifications. Ogni modulo espone interfacce ben definite.

## Principio 8 – Osservabilità

Ogni componente produce log strutturati, metriche, eventi, tracciamento delle richieste.

## Principio 9 – Sicurezza

Ogni richiesta verifica autenticazione, autorizzazione, isolamento dei Workspace, validazione degli input.

## Principio 10 – Evoluzione

Ogni componente sostituibile senza riscrivere l'intero sistema. Contratti stabili, implementazioni sostituibili.

## Regole per il codice

Leggibile, testabile, documentato, prevedibile, facilmente modificabile. La chiarezza ha priorità sulla
complessità.

## Definition of Quality

Test automatici, documentazione aggiornata, monitoraggio, gestione degli errori, conformità al Design
System, prestazioni adeguate.

## Visione Finale

L'architettura deve permettere al prodotto di crescere per anni senza richiedere continue riscritture.
