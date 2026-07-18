# Capitolo 24 – Integration & Agent Platform

## Obiettivo

Trasformare la piattaforma in un hub centrale capace di collegare strumenti, dati e servizi esterni,
mantenendo un'unica esperienza utente coerente.

## Principio Fondamentale

L'obiettivo non è sostituire ogni applicazione, ma comprenderle, collegarle e utilizzarle nel contesto
corretto. Ogni integrazione deve rafforzare il Workspace, non creare nuovi silos.

## Livelli di integrazione

**Livello 1 – Lettura**: la piattaforma legge dati esterni (email, calendario, cloud storage, documenti
condivisi) senza modificare i dati originali.

**Livello 2 – Azioni**: l'AI propone azioni sui servizi collegati (creare evento, bozza email,
aggiornare attività, archiviare documento). Conferma richiesta quando modifica dati esterni.

**Livello 3 – Automazioni**: flussi di lavoro definiti dall'utente (es. "quando arriva un contratto,
crea un Workspace dedicato"). Devono essere semplici da comprendere e modificare.

## Gli Agenti

Ogni agente ha: scopo, strumenti autorizzati, istruzioni dedicate, limiti operativi. Condividono lo
stesso contesto del Workspace ma con competenze differenti.

**Esempi**: Research Agent (analizza fonti, prepara briefing), Meeting Agent (prepara riunioni, genera
verbali), Writing Agent (supporta scrittura documenti/email), Project Agent (monitora stato progetti,
segnala blocchi), Knowledge Agent (mantiene aggiornato il Knowledge Graph, individua duplicati).

## Permessi

Per ogni Workspace, configurabile: quali dati un agente può leggere, quali strumenti usare, quali azioni
proporre o eseguire previa conferma.

## Marketplace (futuro)

Ogni agente installabile dovrà dichiarare: capacità, dati utilizzati, servizi integrati, autorizzazioni
richieste. Rende il sistema trasparente e verificabile.

## API per gli sviluppatori

Creare Workspace, caricare documenti, interrogare il Knowledge Graph, avviare workflow, ricevere eventi.
Versionate e documentate.

## Eventi

Ogni azione significativa genera un evento (documento caricato, task completato, memoria aggiornata,
agente eseguito, integrazione sincronizzata) — alimentano automazioni e notifiche.

## Affidabilità

Se un'integrazione non è disponibile: il Workspace continua a funzionare, il sistema informa l'utente,
la sincronizzazione riprende automaticamente quando possibile.

## Visione Finale

La piattaforma non sarà definita dal numero di integrazioni disponibili, ma dalla capacità di
trasformare strumenti separati in un'unica esperienza di lavoro, mantenendo sempre il controllo del
proprio contesto.

## Note tecniche

- Coerente con il PRD: marketplace, automazioni avanzate e integrazioni CRM sono esclusi dall'MVP.
  Il "Livello 1 (lettura)" non è esplicitamente incluso né escluso — da chiarire.
- Il "sistema di eventi" qui descritto sovrappone concettualmente il Timeline Event del Domain Model
  (cap. 12) — chiarire se sono la stessa entità vista da due angolazioni (Timeline per l'utente, Eventi
  per automazioni/sviluppatori) o due sistemi paralleli da consolidare.
- Il modello di permessi per agente (specialmente in vista del marketplace di terze parti) richiede
  enforcement lato server, non solo dichiarazione — un agente non deve poter leggere oltre quanto
  dichiarato indipendentemente da cosa promette. Da trattare esplicitamente nel capitolo sicurezza.
