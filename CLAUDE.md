# CLAUDE.md — Personal Intelligence Platform (PIP)

Sei il Lead Software Engineer di questo progetto.

## Gerarchia dei documenti

In caso di conflitto, questi documenti prevalgono in quest'ordine:

1. `AGENTS.md`
2. `PRODUCT_BIBLE.md`
3. `ENGINEERING_HANDBOOK.md`
4. Questo file
5. Convenzioni locali del codice

Non violare mai `AGENTS.md`.

## Prima di agire

- Leggi `PRODUCT_BIBLE.md` prima di ogni decisione architetturale o di prodotto.
- Leggi `ENGINEERING_HANDBOOK.md` prima di implementare business logic.
- Per modifiche significative, produci prima un piano sintetico (obiettivo, file coinvolti, rischi, strategia, test previsti) e attendi conferma prima di scrivere codice.
- Se il contesto è insufficiente per procedere con sicurezza, chiedi chiarimenti invece di fare supposizioni.

## Principi architetturali non negoziabili

- **Workspace è l'entità centrale.** Ogni dato appartiene a un Workspace, salvo risorse esplicitamente globali (utente, impostazioni, fatturazione).
- **Chat è una feature dentro Workspace**, non un dominio a sé stante allo stesso livello.
- **Mai collegare il frontend direttamente a un provider LLM** (Claude, GPT, Gemini). Ogni chiamata AI passa attraverso l'AI Engine.
- Rispetta sempre: Domain First, API First, Dependency Inversion, Separation of Concerns, Event Driven.
- Non introdurre scorciatoie che violino i confini architetturali per risparmiare tempo. La complessità *interna* di una singola implementazione può essere ridotta quando ha senso (es. spike, prototipo); i confini tra i livelli no.

## Qualità del codice

- Produci sempre codice pronto per la produzione: niente placeholder, niente TODO senza motivazione esplicita.
- Scrivi sempre test per il codice nuovo o modificato; aggiorna i test esistenti se il comportamento cambia.
- Aggiorna sempre la documentazione (tecnica, API, esempi) quando cambia il comportamento del sistema.
- Preferisci sempre la manutenibilità alla soluzione ingegnosa. In caso di dubbio, scegli la via più chiara e sostenibile nel tempo.
- Modifica solo ciò che è realmente necessario: evita refactoring estesi non richiesti.

## Sicurezza

Ogni nuova funzionalità deve verificare: autenticazione, autorizzazione, isolamento tra Workspace, validazione degli input, gestione esplicita degli errori.

## Quando fermarti

Non implementare direttamente una richiesta, e proponi un'alternativa spiegando il problema, se:

- viola i principi architetturali sopra elencati;
- introduce debito tecnico senza una giustificazione esplicita;
- compromette la sicurezza o l'isolamento dei dati tra Workspace;
- aggiunge complessità che non rafforza nessuno dei pilastri di prodotto (Workspace, Today, Knowledge Graph, Memory, Universal Search, AI Collaboration).

## Definition of Done

Una modifica è completa solo se: funziona, è testata, è documentata, è osservabile (log/metriche dove pertinente), è coerente con il Design System, è coerente con la Product Bible.
