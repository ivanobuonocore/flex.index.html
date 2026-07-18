# Capitolo 11 – User Stories e Flussi Funzionali

## Obiettivo

Descrivere ogni azione possibile dell'utente e la risposta attesa dal sistema. Ogni User Story include:
obiettivo dell'utente, flusso principale, eccezioni, comportamento dell'AI, risultato finale.

## US-001 – Registrazione

Come nuovo utente voglio creare un account per iniziare a usare l'assistente.

**Flusso**: apertura app → login (Google/Apple/Email) → accettazione termini → creazione profilo →
accesso a Today.

**Eccezioni**: email già registrata; errore di rete; autenticazione annullata.

## US-002 – Creazione Workspace

**Flusso**: tocca "+" → "Nuovo Workspace" → nome/icona/descrizione/categoria → il sistema crea il
Workspace → l'AI propone un messaggio di benvenuto e suggerisce sezioni utili.

## US-003 – Conversazione con l'AI

**Flusso**: apertura chat → invio messaggio → streaming risposta → salvataggio cronologia.

**Azioni contestuali**: l'AI può proporre creare una nota, aggiungere attività, promemoria, salvare
documento, collegare la conversazione a un Workspace. L'utente conferma o ignora.

## US-004 – Caricamento documento

**Flusso**: selezione file → upload → analisi automatica → estrazione testo (fallback OCR se
l'estrazione fallisce; notifica utente se anche l'OCR fallisce) → indicizzazione → disponibile in
ricerca e Knowledge Base del Workspace.

## US-005 – Ricerca universale

L'utente inserisce una parola chiave; il sistema restituisce risultati raggruppati per Workspace, Chat,
Documenti, Note, Task, Memoria, Persone. Filtrabili e ordinabili.

## US-006 – Creazione attività

Manuale o accettando un suggerimento AI. Campi: titolo, descrizione, data, priorità, Workspace.

## US-007 – Memoria

L'utente decide se un'informazione deve essere ricordata: globale, legata a un Workspace, o temporanea.
Sempre modificabile o eliminabile.

## US-008 – Daily Brief

All'apertura dell'app, riepilogo automatico con attività imminenti, promemoria, documenti recenti,
Workspace attivi, suggerimenti AI.

## US-009 – Agenti AI

Apre sezione Agenti → sceglie un agente → avvia conversazione. L'agente usa il proprio prompt di sistema,
gli strumenti autorizzati e, se previsto, la memoria del Workspace.

## US-010 – Condivisione Workspace (Business)

L'utente invita un collaboratore. Ruoli: Proprietario, Amministratore, Editor, Lettore — ognuno con
permessi differenti.

## Flussi trasversali

**Offline**: modifiche salvate localmente; alla riconnessione sincronizzazione automatica con gestione conflitti.

**Eliminazione**: ogni elemento eliminato passa prima nel Cestino, ripristinabile entro un periodo configurabile.

**Notifiche intelligenti**: inviate solo quando realmente utili (attività in scadenza, documento
aggiornato, suggerimento AI rilevante).

## Regola generale

L'AI non esegue azioni irreversibili senza conferma dell'utente. Ogni suggerimento è esplicito,
contestuale e facilmente annullabile.

> ⚠️ Nota: le "eccezioni" sono dettagliate finora solo per US-001. Da completare per le altre user
> stories, in particolare US-004 (upload) e US-010 (condivisione), dove i casi di fallimento sono più numerosi.
