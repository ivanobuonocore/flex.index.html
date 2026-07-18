# Product Requirements Document (PRD) — Versione 1.0 (MVP)

## Vision

Creare il miglior assistente personale AI per organizzare lavoro e vita privata attraverso Workspace
intelligenti. L'obiettivo della V1 non è competere con tutti gli strumenti esistenti, ma offrire
un'esperienza semplice, veloce e affidabile che gli utenti desiderino usare ogni giorno.

## Problema

Oggi gli utenti hanno informazioni sparse tra Chat AI, Note, Calendari, File, Email, Task manager. Il
contesto si perde facilmente; l'utente deve ricostruirlo ogni volta.

## Soluzione

Un'unica applicazione dove ogni progetto è un Workspace che riunisce conversazioni, documenti, note,
attività, memoria, AI. L'utente ritrova tutto nello stesso contesto.

## Utente Target

- **Primario**: professionisti e freelance
- **Secondario**: studenti
- **Successivo**: piccoli team (funzionalità Business introdotte dopo aver validato l'uso individuale)

## Cosa deve fare la V1

Creare Workspace; avviare conversazioni AI; caricare documenti; ottenere riassunti e analisi; creare
attività; consultare una schermata Today con riepiloghi; effettuare ricerca globale; utilizzare la
memoria dell'assistente.

## Cosa NON entra nella V1

Collaborazione multiutente, marketplace di agenti, automazioni avanzate, integrazioni con CRM, plugin di
terze parti, editing collaborativo, workflow complessi, dashboard analitiche evolute. Sviluppati solo
dopo aver validato il prodotto.

## Esperienza Chiave

Un nuovo utente deve poter: registrarsi → creare un Workspace → parlare con l'AI → caricare un documento
→ ricevere un suggerimento utile → ritrovare tutto il giorno successivo in Today. Se questo flusso è
eccellente, la V1 ha raggiunto il suo obiettivo.

## KPI di Prodotto

DAU, MAU, retention a 7 e 30 giorni, numero medio di Workspace creati, documenti caricati, tempo medio di
utilizzo, % di suggerimenti AI accettati, tempo alla prima risposta AI.

## KPI Tecnici

Avvio app < 2s; inizio streaming AI < 1s (quando possibile); ricerca < 100ms sui dati locali; crash rate < 0,5%.

## Piano Free

Workspace limitati, limite mensile utilizzo AI, memoria limitata, upload documenti limitato. Obiettivo:
far percepire rapidamente il valore del prodotto.

## Piano Pro

Workspace illimitati, memoria estesa, limiti AI molto più alti, documenti avanzati, agenti personalizzati,
priorità sulle nuove funzionalità.

## Rischi

**Tecnici**: costo delle API AI, latenza, gestione della memoria, ricerca semantica.
**Di prodotto**: eccessiva complessità, onboarding poco chiaro, valore percepito insufficiente.
**Mitigazione**: test continui con utenti reali e iterazioni rapide.

## Roadmap

Fase 1 MVP interno → Fase 2 Beta privata → Fase 3 Beta pubblica → Fase 4 Lancio ufficiale → Fase 5
Collaborazione e integrazioni.

## Criterio di Successo

Il prodotto sarà considerato validato quando una percentuale significativa degli utenti tornerà
spontaneamente ogni giorno perché considera l'app il punto di partenza per organizzare il proprio lavoro
o la propria vita digitale.

## Regola Finale

Ogni nuova funzionalità dovrà rispondere a: "Rende davvero più facile organizzare e usare le informazioni
dell'utente?" Se la risposta è no, non entra nel prodotto.
