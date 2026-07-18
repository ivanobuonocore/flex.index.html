# Capitolo 16 – Development Roadmap

## Obiettivo

Trasformare la visione del prodotto in un piano di sviluppo incrementale, riducendo rischi e tempi di
rilascio. Ogni fase deve produrre un'app funzionante e utilizzabile.

## Fase 0 – Fondazioni

Repository, CI/CD, Flutter, Backend, Supabase, Design System, Autenticazione, Analytics, Crash
Reporting, Feature Flags, ambienti Dev/Staging/Production.

**Deliverable**: applicazione funzionante con login e architettura completa.

## Fase 1 – MVP

Login, Today, Workspace, Conversazioni AI, Upload documenti, Ricerca, Memoria, Task, Profilo.

**Deliverable**: prima versione testabile internamente.

## Fase 2 – Beta Privata

Raccolta feedback, correzione bug, ottimizzazione UX, miglioramento prestazioni e prompt AI.

**KPI**: retention 7 giorni, workspace creati, tempo medio di utilizzo, feedback qualitativo.

## Fase 3 – Beta Pubblica

Accesso tramite invito. Nuove funzioni: Workspace condivisi, Agenti personalizzati, ricerca semantica
avanzata, Daily Brief evoluto, notifiche intelligenti.

## Fase 4 – Versione 1.0

Primo rilascio ufficiale. Requisiti: stabilità, prestazioni, sicurezza, documentazione completa,
assistenza utenti.

## Fase 5 – Crescita

Applicazione Web, Desktop, API pubbliche, Marketplace di Agenti, integrazioni.

## Fase 6 – Enterprise

SSO, Audit Log, ruoli avanzati, Workspace aziendali, controllo amministrativo, SLA.

## Priorità

**Alta**: Workspace, Chat, Documenti, Ricerca, Today, Memoria, Task.
**Media**: Agenti, Timeline, Knowledge Base avanzata, Voice.
**Bassa**: Marketplace, Plugin, Workflow, Automazioni avanzate.

## Criteri di rilascio

Ogni funzionalità deve soddisfare: test automatici, test manuali, verifica UX, verifica sicurezza,
monitoraggio prestazioni.

## Metriche

**Tecniche**: crash rate, tempo risposta AI, latenza API, tempo sincronizzazione, consumo token.
**Di prodotto**: DAU, MAU, retention, workspace attivi, documenti caricati, attività completate,
conversione Free→Pro.

## Gestione del debito tecnico

Ogni sprint dedica circa il 20% della capacità del team a refactoring, aggiornamento dipendenze,
miglioramento test, ottimizzazione prestazioni, documentazione.

## Regola Finale

Il ritmo di sviluppo non deve compromettere la qualità. Una funzionalità rilasciata in ritardo ma
stabile è preferibile a una funzionalità rilasciata rapidamente ma difficile da mantenere.

> ⚠️ Il Capitolo 19 (Knowledge Graph) non è esplicitamente collocato in nessuna fase qui — solo
> "ricerca semantica avanzata" compare in Fase 3. Da chiarire se e quando il Knowledge Graph completo
> entra nel piano.
