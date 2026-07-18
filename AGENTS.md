# AGENTS.md — Repository Operating Rules

Questo repository contiene il codice sorgente della piattaforma **Personal Intelligence Platform (PIP)**.

Ogni modifica deve rispettare la Product Bible, l'Engineering Handbook e il Claude Code Playbook.

In caso di conflitto, prevalgono questi documenti nell'ordine seguente:

1. Product Bible
2. Engineering Constitution
3. Engineering Handbook
4. Claude Code Playbook
5. Convenzioni del repository

## 1. Filosofia del progetto

Questo prodotto non è un chatbot. È una piattaforma centrata sul Workspace.

Ogni scelta progettuale deve rafforzare almeno uno di questi pilastri:

- Workspace
- Today
- Knowledge Graph
- Memory
- Universal Search
- AI Collaboration

Se una modifica non rafforza almeno uno di questi elementi, rivalutala prima di implementarla.

## 2. Prima di scrivere codice

Per ogni attività significativa:

- comprendi il problema;
- individua il dominio coinvolto;
- identifica file e moduli interessati;
- valuta l'impatto sulle funzionalità esistenti;
- proponi un piano sintetico.

Non iniziare direttamente a programmare.

## 3. Architettura

Rispetta sempre: Domain First, API First, Modularità, Dependency Inversion, Separation of Concerns, Event Driven.

Non creare scorciatoie.

## 4. AI Engine

Non collegare mai direttamente il codice applicativo a GPT, Claude, Gemini o altri provider.

Ogni richiesta AI deve passare attraverso l'AI Engine. Questo permette: fallback, monitoraggio costi, cambio modello, logging, osservabilità.

## 5. Workspace

Ogni dato deve appartenere a un Workspace. Evita risorse "globali" salvo quelle espressamente previste (utente, impostazioni, fatturazione).

## 6. Test

Ogni modifica deve verificare: test unitari, test di integrazione, regressioni. Quando opportuno, aggiungi nuovi test.

## 7. Documentazione

Se cambia il comportamento del sistema: aggiorna la documentazione, aggiorna gli esempi, aggiorna eventuali diagrammi.

Codice e documentazione devono rimanere sincronizzati.

## 8. Design System

La UI deve utilizzare esclusivamente i componenti del Design System. Non introdurre componenti duplicati.

Se un componente manca, proponine uno nuovo anziché crearne una variante isolata.

## 9. Performance

Prima di introdurre query complesse, sincronizzazioni, polling o rendering costosi, valuta l'impatto sulle prestazioni.

## 10. Sicurezza

Ogni nuova funzionalità deve verificare: autenticazione, autorizzazione, isolamento dei Workspace, validazione input, gestione degli errori.

## 11. Pull Request

Ogni PR deve includere: obiettivo, modifiche effettuate, impatto architetturale, test eseguiti, eventuali rischi, documentazione aggiornata.

## 12. Definition of Done

Una funzionalità è completa solo se: funziona, è testata, è documentata, è osservabile, è coerente con il Design System, è coerente con la Product Bible.

## 13. Quando fermarsi

Se una richiesta viola i principi architetturali, aumenta il debito tecnico senza giustificazione, compromette la sicurezza, o introduce complessità inutile: non implementarla direttamente. Spiega il problema e proponi un'alternativa.

## 14. Regola d'oro

Ogni riga di codice deve rendere il prodotto più semplice, più affidabile, più manutenibile, più utile per l'utente.

In caso di dubbio, scegli sempre la soluzione più chiara e sostenibile nel lungo periodo.
