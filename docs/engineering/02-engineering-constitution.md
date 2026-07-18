# Capitolo 2 – Engineering Constitution

## Scopo

Principi tecnici non negoziabili per ogni modifica al codice sorgente, prodotta da sviluppatori umani o
da strumenti di AI.

> ⚠️ Nota: questo capitolo si sovrappone in larga parte al Capitolo 1 (Architectural Principles) dello
> stesso documento — stessi concetti (dominio indipendente dalla tecnologia, dipendenze verso il centro,
> sicurezza/performance by design) riformulati in stile "articoli". L'unico contenuto realmente nuovo è
> l'Articolo 13 sui contributi generati da AI. Da consolidare in un solo capitolo.

## Articoli principali (sintesi)

1. **Il dominio è sovrano** — indipendente da UI, database, provider AI.
2. **Nessun accoppiamento diretto** — comunicazione tra componenti solo tramite interfacce.
3. **Una responsabilità per componente** — rifattorizzare quando una componente svolge più ruoli.
4. **Le dipendenze puntano verso il centro** — clean architecture: il dominio non conosce Flutter,
   Supabase o un modello AI specifico.
5. **Nessuna logica duplicata** — una regola di business, una sola implementazione.
6. **Ogni errore è gestito** — intercettato, registrato, trasformato in messaggio comprensibile.
7. **Testabilità** — ogni componente testabile in isolamento (mock/stub per dipendenze esterne).
8. **Evoluzione sicura** — modifiche incompatibili tramite migrazione e versionamento.
9. **Performance come requisito** — valutata fin dal progetto, non ottimizzazione finale.
10. **Sicurezza by Design** — autenticazione, autorizzazione, protezione dati, validazione input, audit.
11. **Documentazione continua** — ogni decisione architetturale accompagnata da documentazione aggiornata.
12. **Qualità del codice** — leggibile, coerente, prevedibile, facilmente modificabile ed eliminabile;
    il codice semplice è preferibile al codice ingegnoso.
13. **AI come collaboratore** — gli strumenti di AI accelerano lo sviluppo ma non sostituiscono la
    revisione tecnica. Ogni contributo generato automaticamente va verificato rispetto ad architettura,
    sicurezza, prestazioni, leggibilità, test.

## Revisione del codice

Ogni Pull Request verifica: conformità alla Costituzione, rispetto del Design System, copertura test,
impatto prestazioni, compatibilità API.

## Visione Finale

La qualità del software non dipende dal talento di un singolo sviluppatore, ma dalla presenza di
principi condivisi che guidano ogni decisione tecnica.
