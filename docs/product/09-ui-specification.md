# Capitolo 9 – UI Specification

## Design Philosophy

Ogni schermata rispetta una regola: un solo obiettivo principale per volta. L'utente non deve mai essere
sopraffatto da pulsanti o informazioni.

## Schermata 1 – Today

**Header**: saluto personalizzato, avatar utente, pulsante notifiche. Sotto: barra di ricerca universale.

**Daily Brief**: card principale generata dall'AI. Esempio: "Oggi hai 2 attività importanti, un
documento da rivedere e una riunione alle 15:00." Azioni rapide: continua progetto, apri attività,
visualizza agenda.

**Workspace Recenti**: visualizzazione orizzontale. Ogni card: icona, nome, ultimo aggiornamento, numero
attività aperte, indicatore AI (nuovi suggerimenti).

**Attività Prioritarie**: elenco semplice — titolo, Workspace, scadenza, priorità. Completamento con un
solo tocco.

**Suggerimenti AI**: azioni contestuali, es. "Riprendi il business plan.", "Archivia il contratto.",
"Pianifica la prossima riunione."

## Schermata 2 – Chat

**Header**: titolo conversazione, nome Workspace (se associato), modello AI in uso, menu rapido.

**Area Messaggi**: utente a destra, AI a sinistra. Supporto completo a: codice, tabelle, immagini, PDF,
checklist, grafici, citazioni.

**Composer**: campo espandibile con allega file, fotocamera, registrazione vocale, comando rapido, invio.
Altezza cresce automaticamente durante la digitazione.

**Barra Contestuale AI**: card discreta quando l'AI riconosce un'opportunità, es. "Vuoi trasformare
questa risposta in una nota?" — conferma con un solo tocco.

## Schermata 3 – Workspace

**Hero Header**: icona, nome, descrizione, stato, ultima attività.

**Dashboard**: griglia di Chat, Documenti, Task, Calendario, Knowledge Base, Memoria, Timeline,
Statistiche — ogni sezione mostra un riepilogo senza obbligare ad aprirla.

**Timeline**: cronologia completa del Workspace (documento aggiunto, attività completata, conversazione
importante, promemoria creato, suggerimento AI accettato).

## Schermata 4 – Ricerca

Sempre disponibile. Risultati raggruppati in: Workspace, Chat, Documenti, Note, Task, Memoria, Persone.
Filtri rapidi: data, tipo, tag, AI.

## Schermata 5 – Documento

Layout di lettura: colonna principale (contenuto) + pannello laterale (riepilogo AI, punti chiave,
domande suggerite, collegamenti ad altri Workspace). Azioni: riassumi, traduci, confronta, salva nella
Knowledge Base, crea attività.

## Schermata 6 – Agenti AI

Ogni agente è una card: nome, specializzazione, strumenti disponibili, Workspace collegati, ultime
attività. L'utente può crearne uno nuovo tramite procedura guidata.

## Schermata 7 – Profilo

Sezioni: Account, Abbonamento, Memoria, Privacy, Integrazioni, Tema, Backup, Dispositivi.

## Pattern comuni

Ogni schermata usa gli stessi componenti: card, pulsanti, menu, badge, chip, dialoghi, bottom sheet.
Garantisce coerenza visiva.

## Responsive

Adattamento automatico a smartphone, tablet, desktop, web. Su schermi grandi compare un pannello
laterale con la navigazione, senza modificare il comportamento dell'app.

## Regola d'oro

Ogni nuova funzione deve integrarsi nei componenti esistenti. Mai introdurre uno stile diverso o una
navigazione parallela. La coerenza dell'esperienza utente ha sempre la priorità rispetto all'aggiunta di
nuove funzionalità.
