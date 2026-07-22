# Capitolo 5 – Design System

## Filosofia del Design

Il design dovrà trasmettere tre sensazioni: Ordine, Intelligenza, Velocità. L'utente dovrà percepire
l'app come un ambiente premium, pulito e rilassante. L'interfaccia dovrà eliminare il rumore visivo e
mettere al centro il contenuto.

## Design Principles

Ogni elemento dell'interfaccia dovrà rispettare: semplicità, coerenza, leggibilità, fluidità,
accessibilità. Mai inserire elementi decorativi senza una funzione.

## Stile

Minimalismo moderno. Ispirazioni: Apple Human Interface Guidelines, Material Design 3, Linear, Notion,
Arc Browser. L'obiettivo non è copiare nessuno, ma combinare le migliori idee in un'esperienza originale.

## Palette Colori (versione aggiornata rispetto al Capitolo 3)

**Light Mode**
- Background principale: `#FAFAFA`
- Card: `#FFFFFF`
- Primario: `#2563EB`
- Secondario: `#7C3AED`
- Testo principale: `#111827`
- Testo secondario: `#6B7280`
- Successo: `#22C55E`
- Attenzione: `#F59E0B`
- Errore: `#EF4444`

**Dark Mode**
- Background: `#111827`
- Card: `#1F2937`
- Primario: `#60A5FA`
- Secondario: `#A78BFA`
- Testo: `#F9FAFB`

> ⚠️ Palette da consolidare con quella del Capitolo 3 (Blu Notte `#1E3A8A` / Azzurro `#38BDF8`).

**Aggiornato** (redesign estetico 2.0 — richiesta esplicita dell'utente: "molto tecnologica",
ispirata a Planito): nuovo gradiente "hero" (`#2563EB` → `#7C3AED`, stessa famiglia cromatica del
glow del pulsante Chat), usato per l'AppBar di Chat/Bilancio, le bolle utente in Chat e il saldo
in evidenza nel Bilancio — comune a entrambi i temi, come il gradiente del pulsante Chat.

**Aggiornato di nuovo, poi corretto** (richiesta esplicita dell'utente: prima il grafico del
Bilancio "con i colori che stai usando stile Siri" — palette multicolore `siriGlow` — poi "usa una
sola palette di colori blu che tende al viola"): il grafico a torta usa ora solo `heroGradient`
(blu/viola), non più la palette a quattro colori del pulsante Chat: entrate in blu, uscite in
viola, con un'ombra sagomata sul donut stesso (non solo un alone rettangolare intorno) per la
profondità richiesta. Il pulsante Chat resta l'unico punto dell'app con `siriGlow` (più colori,
animato).

**Aggiornato ancora** (richiesta esplicita dell'utente: feedback al tocco/cursore sul grafico, e
un dettaglio raggiungibile dalle pillole Entrate/Uscite) — il grafico a torta del Bilancio
risponde al tocco/hover di una fetta ingrandendola leggermente e sostituendo il "Netto" al centro
con l'etichetta e l'importo di quella fetta; le pillole Entrate/Uscite dell'hero aprono, se
toccate, un elenco delle categorie di quel tipo ordinate per importo. Nel calendario di
Appuntamenti il giorno "oggi" è ora solo un piccolo pallino (non più un bordo pieno, che lo
confondeva visivamente con i giorni con impegni): un giorno con almeno un promemoria ha invece uno
sfondo pieno tinto, più caratteristico.

## Tipografia

**Aggiornato** (redesign estetico — richiesta esplicita dell'utente: "utilizzando un font
dedicato"): font principale Manrope, caricato via `google_fonts` (nessun asset da bundlare nel
repo). Sostituisce il precedente riferimento a Inter, mai effettivamente bundlato.

Gerarchia: Display, Heading 1, Heading 2, Heading 3, Body, Caption. Ogni livello con spaziature coerenti.

## Bordi

Radius standard: 16px. Card Premium: 24px. Pulsanti: 14px. Input: 16px.

## Ombre

Leggere, diffuse, mai troppo evidenti. L'interfaccia deve sembrare "leggera".

**Aggiornato** (redesign estetico 2.0): oltre all'ombra neutra di base, un alone colorato più
profondo (`AppShadows.glow`) per le sole superfici "hero" in primo piano (AppBar, saldo nel
Bilancio) — usarlo ovunque annullerebbe l'effetto di rilievo che dà a un singolo elemento.

## Icone

Stile outline, linee sottili, stessa famiglia grafica. Dimensioni standard: 20px, 24px, 32px.

**Aggiornato** (redesign estetico — richiesta esplicita dell'utente: "icone colorate"): le icone
non sono più uniformemente monocromatiche. Ogni sezione fissa (Bilancio/Appuntamenti/Attività/
Documenti, Fase 3 slice 7A) e ogni categoria di Transazione (Fase 3 slice 7C) ha un colore
distintivo; le 4 voci laterali della Bottom Navigation si colorano quando selezionate. Resta
outline lo stile di base — il colore è il segnale, non la forma.

## Animazioni

Durata 180–250ms. Curve morbide. Ogni animazione deve avere uno scopo.

## Bottom Navigation

Cinque sezioni principali: Today, Chat, Workspace, Ricerca, Profilo. Sempre accessibile.

**Aggiornato** (redesign estetico — richiesta esplicita dell'utente: "inseriscila al centro...
mettila in risalto magari all'interno di un cerchio"): ordine Workspace, Bilancio, **Chat (al
centro)**, Ricerca, Profilo. Chat non è una voce come le altre: un cerchio sollevato sopra la
barra, con un gradiente ispirato al "glow" di Siri quando si attiva — comunica visivamente che è
il punto di partenza dell'app (coerente con "la funzione principale deve essere la chat", Fase 3
slice 4), non una quinta scheda intercambiabile con le altre.

**Aggiornato di nuovo**: "Workspace" è ora "Spazi" (etichetta e icona `space_dashboard`, richiesta
esplicita dell'utente di un termine diverso — il modello di dominio e le route restano
"Workspace", solo il testo visibile cambia). La barra ha inoltre un alone blu tenue centrato sul
pulsante Chat (la barra "emana" dal pulsante) e le 4 voci laterali sono più piccole quando non
selezionate — rinforza che la Chat è l'attività centrale, le altre sezioni un contorno.

## Floating Action Button

Un solo pulsante per: Nuova chat, Nuovo Workspace, Nuova nota, Nuovo documento. L'utente sceglie cosa
creare tramite un menu elegante.

## Campo Messaggio

Molto grande, espandibile, con: allegati, voce, fotocamera, invio.

## Card Workspace

Mostra: nome, icona, ultima attività, numero documenti, numero attività, AI dedicata, stato. Con un
colpo d'occhio l'utente capisce dove riprendere il lavoro.

**Aggiornato** (richiesta esplicita dell'utente: "rendi tutto più professionale"): superficie
neutra con ombra neutra (non un alone colorato per categoria, ritenuto poco professionale) e una
sottile barra di accento a sinistra nel colore della categoria — la categoria resta riconoscibile
senza che ogni card "urli" un colore diverso.

## Ricerca

Barra presente ovunque. Risultati raggruppati per categoria: chat, workspace, documenti, attività,
memoria, agenti.

## Stati dell'app

Ogni schermata prevede: Loading, Empty, Errore, Offline, Contenuto — ognuno con design dedicato.

## Accessibilità

Supporto completo a: Dynamic Type, Screen Reader, contrasto elevato, navigazione da tastiera (Web),
touch target ampi.

## Esperienza Premium

Ogni interazione deve trasmettere qualità. Le animazioni non devono mai rallentare il lavoro. Il design
deve mettere in evidenza il contenuto e non l'interfaccia.

## Regola Finale

L'utente non dovrà mai chiedersi "dove trovo questa funzione?". Ogni elemento importante dovrà essere
intuitivo, coerente e facilmente raggiungibile.
