# Capitolo 12 – Domain Model

## Obiettivo

Definire le entità fondamentali dell'applicazione, le relazioni tra esse e le responsabilità di ciascun
dominio. Principio guida: ogni informazione appartiene a un contesto preciso ed è collegabile ad altre
informazioni.

## Entità principali

### User
Campi: id, nome, email, avatar, piano (Free/Pro/Business), preferenze, data creazione, ultimo accesso.
Relazioni: possiede Workspace, crea Chat, possiede Memorie, crea Task, utilizza Agenti.

### Workspace
Campi: id, nome, descrizione, icona, categoria, stato, colore (facoltativo), data creazione.
Relazioni: contiene Chat, Documenti, Task, Note, Calendario, Knowledge Base, Timeline, Memoria di Workspace.

### Chat
Campi: id, titolo, modello AI, data creazione, ultimo messaggio, stato.
Relazioni: appartiene a un Workspace (opzionale), contiene Messaggi, può generare Task e Memorie.

### Message
Campi: id, ruolo (utente/AI/sistema), contenuto, timestamp, allegati, token utilizzati, riferimenti a
fonti. Relazioni: appartiene a una Chat.

### Document
Campi: id, nome, tipo, dimensione, percorso storage, hash (deduplicazione), data upload.
Relazioni: appartiene a un Workspace, può essere collegato a una Chat, può essere indicizzato nella
Knowledge Base.

### Task
Campi: id, titolo, descrizione, stato, priorità, scadenza, assegnatario (Business).
Relazioni: appartiene a un Workspace, può essere generata dall'AI, collegata a un Documento o Chat.

### Note
Campi: id, titolo, contenuto, tag, ultima modifica.
Relazioni: appartiene a un Workspace, creata manualmente o dall'AI.

### Memory
Campi: id, contenuto, livello (Globale/Workspace/Conversazione), origine (utente/AI), data aggiornamento.
Relazioni: può appartenere a un User, a un Workspace, collegata a una Chat.

### Transaction
Aggiunta oltre allo scaffold originale (Fase 3, slice "Bilancio" — richiesta reale dell'utente,
ispirata all'app Planito, non nel piano iniziale). Campi: id, tipo (entrata/uscita), descrizione,
importo (centesimi, sempre positivo — il segno lo decide il tipo), valuta (EUR in questa slice),
data, stato (in attesa di conferma/confermata), origine (manuale/AI), **categoria** (Fase 3, slice
7C — set fisso di 10 categorie: Alimentari/Trasporti/Casa/Bollette/Salute/Svago/Shopping/
Istruzione/Stipendio/Altro, non estensibile dall'utente; default "Altro"). Relazioni: appartiene a
un Workspace; se estratta dall'AI Engine da un messaggio di Chat, collegata a quella Chat. Le
transazioni estratte dall'AI nascono "in attesa di conferma" e diventano definitive, contando nel
saldo del Workspace, solo su conferma esplicita dell'utente (AI Constitution, Principio 1); l'AI
classifica anche la categoria, ma un errore di classificazione non impedisce la registrazione.

### WorkspaceMember / WorkspaceInvite
Aggiunte oltre allo scaffold originale (Fase 3, slice "Bilancio condiviso" — richiesta reale
dell'utente: condividere il Bilancio con un'altra persona, mantenendo ciascuno il proprio Bilancio
personale separato). Un Bilancio condiviso è un Workspace libero (categoria
`sharedBalanceCategory`, non una sezione fissa) a cui un secondo utente viene ammesso tramite
[WorkspaceInvite] (codice a uso singolo, con scadenza) → [WorkspaceMember] (appartenenza). Scope
volutamente ridotto: la condivisione riguarda solo le Transazioni di quel Workspace, non
Note/Attività/Documenti, che restano visibili solo al proprietario.

### Agent
Campi: id, nome, descrizione, prompt di sistema, strumenti disponibili, modello AI preferito.
Relazioni: associato a uno o più Workspace, utilizza Memoria, accede alla Knowledge Base autorizzata.

### Calendar Event
Campi: id, titolo, data, ora, durata, promemoria.
Relazioni: appartiene a un Workspace, può derivare da una Task o conversazione.

### Timeline Event
Campi: id, tipo, descrizione, timestamp, autore.
Relazioni: appartiene a un Workspace, può riferirsi a qualsiasi altra entità.

## Relazioni principali

```
User
└── Workspace
    ├── Chat
    │   └── Message
    ├── Document
    ├── Task
    ├── Note
    ├── Calendar Event
    ├── Timeline Event
    ├── Memory
    └── Agent
```

## Principi del modello

1. Ogni entità ha un identificatore univoco.
2. Ogni record ha data di creazione e ultima modifica.
3. Le eliminazioni sono logiche (soft delete), salvo casi specifici.
4. Le relazioni devono essere esplicite.
5. Ogni contenuto deve poter essere ricercato.
6. Le autorizzazioni vengono applicate a livello di dominio, non duplicate in ogni modulo.

## Estensibilità

Il modello è progettato per aggiungere nuove entità (automazioni, integrazioni, workflow) senza
modificare quelle esistenti. Ogni nuovo dominio comunica tramite interfacce ben definite.

## Note tecniche da chiarire prima dello schema DB (docs/database/)

- **Agent↔Workspace** è many-to-many nel testo ma appare 1-a-molti nel diagramma. Serve una tabella di
  giunzione `workspace_agents` (con eventuale configurazione per-workspace).
- **Memory** ha 3 possibili owner (User/Workspace/Chat) con foreign key opzionali separate, più una
  constraint di coerenza col campo "livello".
- **Document.hash**: chiarire lo scope della deduplicazione (per-workspace o globale per utente).
- **Timeline Event** "può riferirsi a qualsiasi altra entità" è un pattern polimorfico — serve
  `entity_type` + `entity_id`, da rendere esplicito nello schema.
