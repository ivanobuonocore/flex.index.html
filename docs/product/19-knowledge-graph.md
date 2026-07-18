# Capitolo 19 – Knowledge Graph & AI Reasoning

## Obiettivo

Trasformare le informazioni dell'utente in una rete di conoscenza strutturata, navigabile e utilizzabile
dall'AI per fornire risposte e suggerimenti realmente contestuali. Il Knowledge Graph non sostituisce i
documenti o le conversazioni: li collega.

## Principio Fondamentale

L'AI non ragiona sui file. L'AI ragiona sulle relazioni. Un contratto, una nota, una conversazione e una
scadenza non sono elementi isolati, ma parti di uno stesso contesto.

## I Nodi del Grafo

Workspace, Conversazione, Documento, Nota, Attività, Evento di calendario, Persona, Azienda, Luogo,
Obiettivo, Decisione, Memoria. Ogni nodo possiede: identificatore univoco, tipo, metadati, timestamp,
livello di attendibilità (quando applicabile).

## Le Relazioni

Es. "appartiene a", "riguarda", "dipende da", "è collegato a", "è stato creato da", "è stato modificato
dopo", "è stato citato in". Ogni relazione può avere: direzione, data, origine (utente o AI), livello di confidenza.

## Costruzione del Grafo

Si aggiorna continuamente da: caricamento documento, conversazioni, creazione attività, modifica note,
eventi di calendario, conferme dell'utente. L'AI propone collegamenti ad alta probabilità; l'utente può
confermarli, modificarli o rifiutarli.

## Ragionamento Contestuale

Passi: 1) analizza la richiesta → 2) individua il Workspace attivo → 3) recupera i nodi direttamente
collegati → 4) espande il grafo entro un limite configurabile → 5) recupera i documenti pertinenti →
6) costruisce il prompt con il solo contesto necessario. Obiettivo: ridurre il rumore e aumentare la
pertinenza.

**Esempio**: "Preparami per la riunione con Rossi." → l'AI recupera automaticamente Workspace corretto,
conversazioni precedenti, contratto collegato, note delle ultime riunioni, attività aperte, scadenze imminenti.

## Knowledge Cards

Ogni nodo visualizzabile come scheda: riepilogo, collegamenti, cronologia, documenti correlati, attività
correlate, persone coinvolte.

## Ragionamento Temporale

L'AI distingue informazioni recenti, storiche, elementi superati, decisioni ancora valide.

## Livelli di Confidenza

Alta (collegamento quasi certo), Media (probabile), Bassa (semplice suggerimento). Le relazioni ad alta
confidenza evidenziate; quelle meno certe richiedono verifica.

## Aggiornamento del Grafo

Se un collegamento viene confermato più volte, aumenta la sua attendibilità; se rimosso, il sistema
evita di riproporlo nelle stesse condizioni.

## Privacy

Il grafo è personale. Informazioni di Workspace differenti restano separate salvo autorizzazione
esplicita. Nelle versioni Business, i permessi si applicano anche ai collegamenti tra nodi.

## Estensibilità

Nuovi tipi di nodo aggiungibili senza modificare il funzionamento del sistema (email, repository Git,
ticket, CRM, altre applicazioni — fasi future).

## Visione Finale

L'AI non deve limitarsi a rispondere a una domanda. Deve comprendere il contesto in cui quella domanda
nasce.

## Note tecniche (da discussione con Claude)

- Il "Ragionamento Contestuale" (passi 1-6) NON richiede un vero graph database semantico: è un pattern
  di *retrieval scoping* implementabile su Postgres relazionale (già nello stack), non serve Neo4j o
  simili almeno nelle fasi iniziali.
- Il punto tecnicamente più delicato è l'**entity linking** ("l'AI propone collegamenti quando rileva
  un'elevata probabilità") — riconoscere che un'entità menzionata è la stessa di un'altra vista altrove.
  Da isolare come rischio tecnico a parte, con un fallback iniziale a conferma sempre esplicita (senza
  auto-collegamento) finché l'accuratezza non è validata con dati reali.
- Il "livello di confidenza che si aggiorna con le conferme utente" è un sistema di feedback/learning:
  chiarire se è per singolo utente o aggregato, e se serve retraining o basta un contatore euristico
  (più semplice, probabilmente sufficiente per MVP+).
- ⚠️ Il Development Roadmap (cap. 16) non colloca esplicitamente questo capitolo in nessuna fase — va
  chiarito se/quando entra nel piano (probabile Fase 5-6, non MVP).
