# Capitolo 15 – Product Principles

## Obiettivo

Definire i principi fondamentali che guidano ogni decisione di design, sviluppo e prodotto. Ogni nuova
funzionalità deve rispettare questi principi. Se li viola, va ripensata.

## Principio 1 – Il contesto viene prima della conversazione

La chat è uno strumento. Il Workspace è il contesto. Ogni conversazione deve poter essere collegata a un
progetto, documenti, attività e conoscenza. Il valore nasce dal contesto, non dalla cronologia dei messaggi.

## Principio 2 – L'AI assiste, non sostituisce

L'AI propone. L'utente decide. Nessuna modifica ai dati, invio messaggi, eliminazione o automazione
irreversibile senza conferma esplicita, salvo autorizzazioni configurate dall'utente.

## Principio 3 – Tutto è collegato

Ogni elemento del sistema può essere collegato ad altri. Un documento può generare attività, note,
eventi, conversazioni, memoria. L'utente non deve duplicare informazioni.

## Principio 4 – Una sola ricerca

L'utente non deve chiedersi dove cercare. Una ricerca trova tutto ciò a cui ha accesso: Workspace,
conversazioni, documenti, note, attività, memoria.

## Principio 5 – Memoria trasparente

Ogni informazione ricordata dall'AI deve essere visibile, modificabile, eliminabile. L'utente mantiene
sempre il controllo della propria memoria digitale.

## Principio 6 – Ogni suggerimento deve essere utile

L'AI non interrompe, non invia notifiche superflue, non propone azioni prive di valore. Ogni
suggerimento deve ridurre il lavoro dell'utente. (Misurato dalla metrica "% suggerimenti AI accettati" nel PRD.)

## Principio 7 – Mobile-first, non mobile-only

L'esperienza nasce sullo smartphone, ma cresce verso tablet, desktop, web. Le stesse funzionalità si
adattano ai diversi dispositivi.

## Principio 8 – Prestazioni percepite

Apertura immediata, caricamento progressivo, streaming delle risposte AI, cache intelligente,
sincronizzazione in background.

## Principio 9 – Privacy come caratteristica del prodotto

Non solo un requisito normativo, ma una funzionalità. L'utente sa: quali dati vengono utilizzati,
perché, come rimuoverli.

## Principio 10 – Evoluzione continua

Il sistema accoglie nuovi modelli AI, strumenti, integrazioni, agenti — senza costringere l'utente a
imparare una nuova interfaccia.

## Decision Filter

Prima di approvare una nuova funzionalità, rispondere a cinque domande:
1. Riduce il tempo necessario per completare un'attività?
2. Migliora il contesto disponibile per l'AI?
3. È comprensibile senza tutorial?
4. Mantiene la coerenza con il resto del prodotto?
5. Aggiunge valore reale alla V1 o può aspettare?

Se la maggioranza delle risposte è negativa, la funzionalità viene rimandata.

> Nota: esistono altre due versioni di questo stesso filtro decisionale (nel PRD, in modo implicito, e
> nel Capitolo 22 — Product Decision Framework, con una matrice pesata più operativa). Il Capitolo 22 è
> probabilmente la versione da tenere come riferimento unico.

## North Star

L'obiettivo non è avere più funzioni. È permettere all'utente di ritrovare informazioni, prendere
decisioni e portare a termine il proprio lavoro con meno attrito possibile.
