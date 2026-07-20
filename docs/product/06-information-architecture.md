# Capitolo 6 – Information Architecture

## Obiettivo

L'utente non deve mai sentirsi perso. Ogni funzione deve avere una posizione logica. Ogni schermata deve
essere raggiungibile in pochi tocchi. L'intera applicazione è costruita attorno al concetto:
**Workspace + AI**.

## Struttura generale

**Aggiornato** (richiesta esplicita dell'utente — "la funzione principale deve essere la chat"):
cinque aree principali, sempre accessibili dalla barra inferiore: **Chat** (Home), Workspace,
Ricerca, **Bilancio**, Profilo. "Today" non è più un'area separata: il suo contenuto (saluto,
Workspace recenti) confluisce in testa alla Home Chat, che diventa così il vero punto di ingresso
dell'app — coerente con "Struttura generale... Workspace + AI", dove l'AI si esprime
concretamente attraverso la conversazione. "Bilancio" è una quinta voce aggiunta oltre alla
roadmap originale (richiesta esplicita dell'utente: un "prospetto di entrate e di uscite" con un
grafico a torta): aggrega le transazioni confermate di tutti i Workspace, a differenza del
Bilancio per Workspace già presente nelle "cartelle" di una Chat.

## Chat (Home)

Prima schermata dopo il login. Mostra: saluto personalizzato, Workspace recenti, e tutte le
conversazioni dell'utente (private o collegate a un Workspace) — punto di ingresso reale, non
un elenco di sola consultazione. Da una conversazione collegata a un Workspace, un pulsante
"cartelle" apre Note/Attività/Documenti/Bilancio di quel Workspace senza dover passare dalla tab
Workspace. Ogni conversazione può essere: privata, collegata a un Workspace, condivisa (versione
Business). Contiene: messaggi, file, cronologia, memoria, allegati, voice chat.

## Workspace

Il cuore dell'app. Ogni utente ha sempre 4 **sezioni fisse**, create automaticamente e mostrate in
testa alla Home Chat (striscia "Sezioni") oltre che nella tab Workspace — richiesta esplicita
dell'utente ("non deve essere l'utente a gestire il workspace ma la chat"): **Bilancio**
(entrate/uscite), **Appuntamenti** (calendario), **Attività** (liste/checklist), **Documenti**
(foto e file). Sono popolate scrivendo in Chat, non creandole a mano: rinominabili/personalizzabili,
ma non eliminabili (sono strutturali). Oltre alle sezioni fisse, l'utente può ancora creare
Workspace liberi per progetti specifici (Lavoro, Studio, Personale, Business, Casa, Immobili,
Marketing, Viaggi, qualsiasi argomento) — questi restano rinominabili **ed eliminabili**. Contiene:
AI dedicata, conversazioni, documenti, immagini, note, attività, calendario, Knowledge Base,
memoria, cronologia, obiettivi, statistiche.

## Ricerca

Una sola barra. Cercando "Contratto" si trovano contemporaneamente: messaggi, PDF, Word, Excel, immagini,
workspace, attività, memoria, note, agenti. L'utente non deve mai scegliere prima dove cercare.

## Profilo

Account, abbonamento, tema, impostazioni AI, memoria, privacy, sicurezza, backup, dispositivi collegati,
API personali (utenti avanzati).

## Pulsante +

Sempre presente. Permette di creare: nuova chat, nuovo Workspace, nuova nota, nuovo documento, nuova
attività, nuovo promemoria.

## Home del Workspace

Mostra: nome, descrizione, AI del Workspace, ultima attività, documenti, note, task, cronologia, statistiche.

## Menu Workspace

Chat, Documenti, Attività, Calendario, Knowledge, Memoria, Impostazioni.

## Chat (dettaglio)

Titolo, AI utilizzata, cronologia, messaggi, allegati, prompt preferiti, tag, preferiti.

## Documenti

Formati supportati: PDF, Word, Excel, PowerPoint, testo, immagini, audio, video (versione futura).

## Knowledge Base

Ogni Workspace può avere una propria Knowledge Base. L'AI utilizza quei documenti durante la conversazione.

## Memoria

Tre livelli: Memoria Globale, Memoria Workspace, Memoria Conversazione.

## Agenti AI

L'utente può scegliere: Assistente Generale, Business, Marketing, Immobiliare, Legale, Commercialista,
Programmatore, Tutor, Coach — oppure crearne uno personalizzato.

## Notifiche

Non invasive, intelligenti. Esempi: "Hai un'attività in scadenza.", "Hai lasciato in sospeso il progetto
Marketing.", "L'AI ha trovato una scadenza nel contratto."

## Ricerca Universale

Ogni elemento dell'app deve essere indicizzato. L'utente deve trovare qualsiasi contenuto in pochi secondi.

## Regola fondamentale

Ogni funzione deve appartenere ad una sola sezione. Mai duplicare la navigazione. Mai creare menu
confusi. L'app deve risultare prevedibile e coerente.
