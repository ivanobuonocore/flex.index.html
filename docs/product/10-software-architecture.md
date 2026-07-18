# Capitolo 10 – Software Architecture

## Obiettivo

Costruire una piattaforma AI moderna, scalabile e modulare. Ogni componente deve poter essere sostituito
senza dover riscrivere l'intera applicazione.

## Architettura generale

Sei livelli principali:

```
Flutter App
    │
API Gateway
    │
AI Engine
    │
Business Services
    │
Supabase
    │
Storage
```

> ⚠️ Da valutare: l'API Gateway potrebbe essere ridondante rispetto a quanto Supabase offre già
> nativamente (RLS + Edge Functions). Vedi nota di revisione tecnica in coda al capitolo.

## Frontend — Flutter

Responsabilità: rendering UI, gestione stato, navigazione, cache locale, sincronizzazione offline,
upload file, autenticazione. Il frontend non contiene logica di business complessa.

## API Gateway

Punto di ingresso unico. Responsabilità: autenticazione, autorizzazione, rate limiting, logging,
instradamento richieste, versionamento API.

## AI Engine

Il cervello del sistema. Responsabilità: selezione del modello AI, gestione prompt, memoria,
Retrieval-Augmented Generation (RAG), orchestrazione degli agenti, streaming delle risposte. L'utente
dialoga sempre con un unico assistente, indipendentemente dal modello utilizzato.

## Business Services

Servizi indipendenti con responsabilità isolate: Workspace Service, Chat Service, Document Service,
Search Service, Task Service, Notification Service, Billing Service, Memory Service.

## Database

PostgreSQL tramite Supabase. Principi: normalizzazione, chiavi esterne, soft delete, audit log, timestamp
standardizzati.

## Storage

Ogni file archiviato separatamente dal database. Categorie: Documenti, Immagini, Audio, Video, Allegati,
Backup.

## Ricerca

Indice dedicato: ricerca full-text + ricerca semantica (vector search). Supporto ai filtri. Risultati
ordinati per rilevanza.

## Memoria AI — tre livelli

1. Memoria globale (preferenze permanenti dell'utente)
2. Memoria Workspace (informazioni valide solo all'interno di un progetto)
3. Memoria conversazione (contesto temporaneo della chat)

## Knowledge Base

Ogni Workspace può avere una base di conoscenza dedicata: documenti indicizzati, chunking automatico,
embedding, recupero contestuale durante la conversazione.

## Agenti

Ogni agente possiede: ruolo, prompt di sistema, strumenti autorizzati, Workspace collegati, memoria
dedicata. Condividono la stessa infrastruttura ma hanno comportamenti differenti.

## Sicurezza

Autenticazione tramite Supabase Auth (Email, Google, Apple). Autorizzazioni gestite tramite ruoli e permessi.

## Sincronizzazione

Strategia offline-first: ogni modifica salvata localmente e sincronizzata appena disponibile una connessione.

## Logging

Ogni errore registrato. Metriche: crash, tempi di risposta, utilizzo AI, consumo token, errori API.

## Scalabilità

Ogni servizio scala indipendentemente. Obiettivo: supportare utenti Free, Pro, team, aziende senza
modificare l'architettura di base.

## Regola fondamentale

Ogni nuovo modulo deve poter essere aggiunto senza rompere quelli esistenti. L'architettura privilegia
modularità, osservabilità e facilità di manutenzione.

## Note di revisione tecnica (da discussione con Claude)

- L'API Gateway va giustificato: Supabase espone già API REST/GraphQL con RLS per autenticazione a
  livello DB, più Edge Functions per logica custom. Valutare se un gateway separato risolve un problema
  reale o è complessità prematura.
- L'AI Engine (RAG + orchestrazione multi-agente) è il componente più complesso di tutta l'architettura
  e merita probabilmente un documento tecnico dedicato più approfondito, non solo una sottosezione.
