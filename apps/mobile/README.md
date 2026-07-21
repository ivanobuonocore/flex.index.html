# apps/mobile

App Flutter principale (MVP). Architettura Feature First: ogni feature sotto
`lib/features/<nome>/` con sottocartelle `presentation/ application/ domain/ data/`
(solo quelle necessarie — vedi AI Engineering Playbook).

State management: Riverpod. Routing: GoRouter (`StatefulShellRoute.indexedStack` per la
Bottom Navigation a 5 sezioni).

## Stato

Implementate, con dati reali via Supabase:

- **auth** (Fase 1) — login, registrazione, sessione, logout.
- **workspace** (Fase 1 + Fase 2 slice 1/2, **Sezioni fisse da Fase 3 slice 7A** — richiesta
  esplicita dell'utente) — lista, creazione, Home del Workspace (`/workspace/:id`) con anteprima
  Note/Task/Documenti e menu verso le sezioni non ancora implementate. Ogni utente ha sempre 4
  Workspace di sistema (Bilancio/Appuntamenti/Attività/Documenti — `SystemWorkspaceCategory` in
  `packages/domain`), creati automaticamente al primo accesso (`workspaceBootstrapProvider`, non
  una migrazione: deve valere anche per gli utenti già esistenti). Ogni `WorkspaceCard` ha un menu
  Rinomina (sempre) ed Elimina (solo sui Workspace liberi — le sezioni fisse sono strutturali, non
  eliminabili).
- **note** (Fase 2 slice 1) — CRUD completo per Workspace (`/workspace/:id/notes`), realtime.
- **task** (Fase 2 slice 1) — CRUD completo per Workspace (`/workspace/:id/tasks`), realtime,
  toggle rapido todo↔done.
- **document** (Fase 2 slice 2) — upload/apertura/eliminazione per Workspace
  (`/workspace/:id/documents`), Supabase Storage con signed URL, realtime.
- **search** (Fase 2 slice 3) — Ricerca Universale cross-tabella (Workspace/Note/Task/
  Documenti) via full-text search Postgres, debounce lato UI.
- **chat** (Fase 3 slice 1, foto in slice 3, Home dell'app da slice 4, **Chat unica da slice
  7B** — richiesta esplicita dell'utente: "la chat deve essere unica... in un unico posto tutte
  le attività") — `/chat` (`ChatHomeScreen`) è ora sia la prima schermata dopo il login sia
  l'unica conversazione dell'utente: niente più elenco di chat da scegliere, niente più chat
  per-Workspace. `singleChatProvider` la crea al primo accesso (idempotente: riusa la più recente
  se esistono già chat da prima di questa slice) — nessuna scelta esposta all'utente. In testa,
  sempre visibile, la striscia "Sezioni" (Fase 3 slice 7A) con anteprima viva. Invio messaggio +
  risposta AI in tempo reale (realtime, non streaming token-by-token), indicatore "l'assistente
  sta scrivendo". Il frontend non chiama mai direttamente Anthropic: ogni messaggio passa
  dall'Edge Function `ai-chat` (`infrastructure/supabase/functions/ai-chat`), l'unico punto in cui
  l'app tocca un provider AI — le transazioni riconosciute nel messaggio vanno sempre nella
  sezione Bilancio (il suo Workspace id è passato come contesto all'Edge Function, al posto del
  vecchio `workspaceId` della Chat). Si può allegare una foto a un messaggio: va sempre nella
  sezione Documenti (`Document` con `chat_id`, stesso bucket riusato — nessuna nuova
  infrastruttura) e l'assistente la "vede" tramite il supporto immagini di Claude.
- **chat (scroll automatico)** (bug segnalato dall'utente: "quando risponde non si blocca la
  pagina ma che esca di seguito senza scatti, come una normale conversazione su whatsapp") — la
  lista messaggi scorre automaticamente in fondo a ogni nuovo messaggio (proprio o
  dell'assistente); prima non lo faceva, quindi ogni risposta restava fuori vista finché l'utente
  non scorreva a mano. La bolla "l'assistente sta scrivendo…" è ora l'ultimo elemento della stessa
  lista messaggi (non un widget fisso sotto, che cambiando l'altezza disponibile causava lo
  "scatto" percepito) — appare e scompare nel flusso normale, come la bolla "..." di WhatsApp. La
  striscia "Sezioni" in testa è anche più sottile (56px, non più 128px) e usa una card compatta
  dedicata (`_SectionChip`, solo icona/nome/anteprima — senza il menu Rinomina/Elimina, che resta
  nella tab Workspace) invece della `WorkspaceCard` completa. Il saluto capitalizza sempre il nome
  dell'utente, anche se salvato in minuscolo.
- **transaction** (Fase 3 slice 2, aggiunta oltre allo scaffold originale — richiesta reale
  dell'utente, ispirata all'app Planito) — Bilancio per Workspace (`/workspace/:id/transactions`):
  saldo del mese corrente (entrate meno uscite confermate) + lista con totali separati, aggiunta
  manuale (entrata o uscita), e una sezione "in attesa di conferma" per le transazioni che la
  Chat ha riconosciuto in un messaggio (es. "barbiere 23€, supermercato 35€" oppure "ho ricevuto
  lo stipendio di 1500€") ma che l'utente non ha ancora confermato — nessuna transazione
  suggerita dall'AI conta nel saldo finché non viene confermata esplicitamente (AI Constitution,
  Principio 1).
- **transaction (categorie)** (Fase 3 slice 7C, "Bilancio con categorie" — richiesta esplicita
  dell'utente) — `TransactionCategory` (10 valori fissi: Alimentari/Trasporti/Casa/Bollette/
  Salute/Svago/Shopping/Istruzione/Stipendio/Altro, non estensibile dall'utente). Picker nella
  creazione/modifica manuale (`create_edit_transaction_sheet.dart`); ogni riga del Bilancio (per
  Workspace e globale) mostra la categoria. L'Edge Function `ai-chat` classifica automaticamente
  ogni transazione che estrae dalla Chat (es. "barbiere" → Svago, "supermercato" → Alimentari) —
  una categoria mancante o non riconosciuta ricade su "Altro" invece di far scartare la
  transazione: un errore di classificazione non deve far perdere una spesa reale.
- **notifications** (Fase 3 slice 4, aggiunta oltre allo scaffold originale — richiesta reale
  dell'utente, che ha esplicitamente rifiutato l'alternativa "elenco promemoria solo in app" per
  volere notifiche di sistema vere) — prima slice: attivazione (permesso + iscrizione Web Push) e
  un pulsante "Invia una notifica di prova" nella card "Notifiche" del Profilo. Visibile solo se
  l'app è stata compilata con `VAPID_PUBLIC_KEY` (facoltativa: l'app resta utilizzabile anche
  senza). Non ancora i Promemoria veri (`CalendarEvent`, già modellato in `packages/domain` ma non
  implementato) — questa slice prova solo che la catena di consegna funziona.
- **chat (restyling)** (Fase 3 slice 6, richiesta reale dell'utente — "vorrei che la chat fosse
  più bella esteticamente... stile whatsapp") — sfondo, bolle con effetto "coda" e avatar
  dell'assistente ispirati a WhatsApp, selettore emoji manuale nell'input; l'assistente AI stesso
  ora usa emoji con naturalezza nelle risposte (system prompt aggiornato in `ai-chat`).
- **transaction (Bilancio globale)** (Fase 3 slice 6, oltre al Bilancio per Workspace già
  esistente — richiesta reale dell'utente: un "prospetto di entrate e di uscite" con un grafico a
  torta) — nuova quinta voce di navigazione `/balance`: aggrega le transazioni confermate di
  **tutti** i Workspace in un grafico a torta (`fl_chart`) entrate/uscite più le stesse sezioni
  "in attesa di conferma"/confermate del Bilancio per Workspace, qui etichettate per Workspace di
  provenienza. `TransactionRepository.watchTransactions` accetta ora un `workspaceId` nullable
  (`null` = tutti i Workspace), stesso pattern di `ChatRepository.watchChats`.

- **redesign estetico** (richiesta esplicita dell'utente: "rendi più estetica l'interfaccia con
  icone colorate e utilizzando un font dedicato... inserisci la Chat al centro... in un cerchio...
  con i colori di Siri quando si attiva") — font Manrope via `google_fonts` in tutta l'app
  (`packages/design-system`); Bottom Navigation riordinata: Workspace, Bilancio, **Chat al
  centro** (cerchio con gradiente ispirato al "glow" di Siri, sollevato sopra la barra), Ricerca,
  Profilo (`AppShell`); icone colorate — le 4 voci laterali della barra quando selezionate, le
  categorie di Transazione (badge colorato in ogni riga del Bilancio), Note/Attività/Documenti
  nelle rispettive liste.

- **transaction (Bilancio condiviso)** (Fase 3, "Bilancio condiviso" — richiesta esplicita
  dell'utente: condividere il Bilancio con un'altra persona che ha un proprio account, mantenendo
  ciascuno il proprio Bilancio personale separato) — nuova schermata `SharedBalanceScreen`
  (`/balance/shared`, raggiungibile da un'icona nell'AppBar del Bilancio globale): crea un Bilancio
  condiviso (un Workspace libero, categoria `sharedBalanceCategory`) e mostra subito un codice
  d'invito da condividere, oppure unisciti a uno con un codice ricevuto. La condivisione riguarda
  **solo le Transazioni** — Note/Attività/Documenti restano visibili solo al proprietario, anche
  per un Workspace di cui qualcun altro è membro. Il Bilancio globale (`/balance`) esclude i
  Bilanci condivisi dal totale aggregato: restano due Bilanci separati, mai mescolati. Nuove tabelle
  `workspace_members`/`workspace_invites` e funzione `redeem_workspace_invite` (SECURITY DEFINER) —
  vedi `docs/database/README.md` per il dettaglio delle RLS (additive, non una riscrittura di
  quelle esistenti) e due bug reali trovati e corretti verificando su Postgres locale con due
  utenti simulati (ricorsione infinita tra le RLS di `workspaces`/`workspace_members`, colonna
  ambigua nella funzione di redeem).

- **reminder (Promemoria via Chat)** (Fase 3, "Promemoria via Chat" — CLAUDE.md, richiesta
  esplicita dell'utente di notifiche push vere, non un semplice elenco in app) — nuova
  `ReminderListScreen` (`/workspace/:id/reminders`, sezione "Promemoria" anche nella Home del
  Workspace) per creare/eliminare promemoria manualmente in qualunque Workspace; scrivendo in Chat
  "ricordami di... [orario]" l'assistente li registra da solo nella sezione Appuntamenti (nuovo
  tool Anthropic `create_reminder` in `ai-chat`, stesso principio di `extract_transactions` ma
  senza stato pending/confirmed — un promemoria è reversibile con uno swipe, non un dato
  finanziario). L'invio effettivo della notifica push è una nuova Edge Function,
  `send-due-reminders`, invocata ogni minuto da un cron job Postgres (`pg_cron`) — l'unica function
  di questo progetto che usa la service role, giustificato esplicitamente (nessun JWT utente da
  inoltrare, un cron non è una richiesta autenticata). Vedi `docs/database/README.md` per il
  dettaglio (attivazione del cron, verifiche fatte e non fatte).

- **Redesign estetico 2.0 + Q&A su dati reali in Chat** (richiesta esplicita dell'utente: "la chat
  deve assumere una veste grafica prioritaria", "il Bilancio... deve essere molto tecnologica")
  — Chat Home e Bilancio rivestiti con un gradiente "hero" condiviso (`GradientAppBar`, nuovo
  widget in `shared/widgets/`), bolle utente e saldo con più profondità/ombre colorate, categorie
  come pillole, grafico con il netto al centro del donut. Il pulsante di invio in Chat e il
  pulsante Chat della bottom nav restano invariati (richiesta esplicita). In `ai-chat`, due nuovi
  tool di sola lettura sempre attivi (`query_balance_summary`, `query_reminders`) permettono
  all'assistente di rispondere a domande come "quanto ho speso questo mese" o "ho appuntamenti il
  mese prossimo" citando i dati reali, non inventati — vedi `docs/database/README.md`, Fase 3
  slice 10, per il dettaglio del secondo giro con Anthropic necessario per queste risposte.

- **Redesign estetico 2.0 (seguito, poi corretto)** — un primo giro ha provato una palette
  multicolore ispirata al pulsante Chat (`AppShadows.siriGlow`) per grafico/Workspace/bottom nav;
  **l'utente ha chiesto esplicitamente "una sola palette di colori blu che tende al viola"**, quindi
  `AppShadows.siriGlow` è stata rimossa: ovunque tranne il pulsante Chat (invariato, l'unico con
  gradiente animato a più colori) si usa solo `AppColors.heroGradient`. `WorkspaceCard` sostituisce
  la Card piatta (elevation 0 nel tema globale) con superficie neutra + ombra neutra e una sottile
  barra di accento a sinistra nel colore della categoria (non un alone colorato per categoria: "più
  professionale"); la bottom nav ha un alone blu tenue centrato sul pulsante Chat, le 4 voci
  laterali più piccole da ferme. Corretto anche un rendering mancato: le emoji a colori richiedono
  `flutter build web --web-renderer html` (limitazione nota di CanvasKit, il renderer di default su
  desktop, che non carica i font emoji a colori) — un build era stato fatto senza quel flag, da qui
  l'assenza del colore.

- **Bilancio: storico, pillole, profondità reale nel grafico** (richiesta esplicita dell'utente) —
  tendina del mese di riferimento (sempre include il mese corrente, più ogni mese con almeno una
  transazione confermata) che ricalcola hero/grafico/elenco confermate; le transazioni in attesa di
  conferma restano non filtrate per mese, per design. Le icone +/- accanto a entrate/uscite sono
  emoji (💰/💸). Le transazioni confermate sono ora "pillole" sopraelevate (angoli molto arrotondati
  + ombra) invece della Card piatta. Il grafico ha un'ombra sagomata sul donut stesso (una copia
  scura semi-trasparente dello stesso anello, leggermente spostata) oltre all'alone della Card, per
  un rilievo che segue la forma circolare, non solo il rettangolo intorno.

- **Chat: sezioni nascondibili, Q&A con totale esplicito, "Spazi"** — la striscia "Sezioni" in Chat
  ha un'intestazione con freccia per comprimerla/espanderla (richiesta esplicita dell'utente:
  "vorrei fosse nascondibile"). L'istruzione di `query_balance_summary`/`query_reminders` in
  `ai-chat` ora richiede esplicitamente un totale dichiarato in una frase diretta, non un elenco di
  transazioni (richiesta esplicita: "non soltanto riportarmi le transazioni... ma farmi un
  totale"). "Workspace" è stato rinominato "Spazi" nell'etichetta della bottom nav e nel titolo
  della schermata (icona `space_dashboard`) — nessuna classe/route interna rinominata, solo il
  testo visibile.

- **Appuntamenti: calendario mensile a quadratini** (richiesta esplicita dell'utente: "un
  calendario fatto a quadratini (giorni) dove su ogni giorno viene riportato l'appuntamento") —
  `ReminderListScreen` mostra ora un calendario mensile (nessuna nuova dipendenza pub: fatto a mano
  con `GridView.count`, dato che pub.dev non è raggiungibile in questo sandbox per verificarne una
  nuova) con un puntino sui giorni che hanno almeno un promemoria; toccare un giorno filtra
  l'elenco sotto a quel giorno (toccarlo di nuovo toglie il filtro). Un promemoria scritto in Chat
  (es. "lunedì prossimo devo andare dal barbiere") continua a passare dallo stesso tool
  `create_reminder` di sempre: compare quindi automaticamente nel calendario non appena creato,
  senza bisogno di alcuna modifica lato server. L'invio della notifica push resta quello già
  costruito in precedenza (`send-due-reminders` + `pg_cron`, già configurato dall'utente).

- **Appuntamenti: giorno con impegni più caratteristico, "oggi" con un pallino, feedback al tocco
  del grafico** (richiesta esplicita dell'utente) — nella cella del calendario il giorno di "oggi"
  ora è solo un piccolo pallino sotto il numero (prima aveva un bordo colorato pieno, che lo
  confondeva visivamente con i giorni con impegni); un giorno con almeno un promemoria ha invece
  uno sfondo pieno tinto (`Color.alphaBlend`, deterministico anche sopra sfondi diversi in
  light/dark) — più caratteristico di un semplice puntino. Il grafico a torta del Bilancio
  (`_BalancePieChart`) ora è `Stateful`: toccando/passando il cursore su una fetta
  (`PieTouchData.touchCallback`) il centro del donut mostra l'etichetta e l'importo di quella
  fetta al posto del "Netto" e la fetta toccata si ingrandisce leggermente (`radius` maggiore) —
  nessun nuovo widget esterno, solo stato locale.

- **Bilancio: dettaglio per categoria; Appuntamenti: stato notifiche** (richiesta esplicita
  dell'utente, "2 e 3" di una lista di migliorie proposte) — le pillole Entrate/Uscite dell'hero
  del Bilancio ora sono toccabili (solo se l'importo non è zero): aprono un
  `showModalBottomSheet` con l'elenco delle categorie di quel tipo, ordinate per importo
  decrescente, con percentuale sul totale (nuova funzione pura `amountCentsByCategory` in
  `transaction_controller.dart`, testata separatamente dal widget). In Appuntamenti, un banner
  fisso sopra il calendario (`_NotificationStatusBanner`, gated su `AppEnv.vapidPublicKey`
  esattamente come la card equivalente in Profilo — nessuna nuova infrastruttura) avvisa se le
  notifiche non sono ancora attive o non sono supportate, con un pulsante "Attiva" quando
  possibile: un promemoria creato in Chat compare comunque nel calendario, ma senza notifiche
  attive l'utente non riceverebbe alcun avviso all'orario previsto — meglio dirlo subito. Nessun
  test widget dedicato a questo banner (stessa scelta già fatta per la card equivalente in
  Profilo): lo stato "attivo" dipende da `AppEnv.vapidPublicKey`, una costante di compilazione
  (`String.fromEnvironment`) non sovrascrivibile nella normale esecuzione di `flutter test`.

- **search (Transazioni + Promemoria)** (richiesta esplicita dell'utente) — la Ricerca
  Universale ora trova anche le Transazioni confermate (le pending restano escluse, sono
  suggerimenti non ancora decisi) e i Promemoria, oltre a Workspace/Note/Attività/Documenti già
  esistenti. `search_workspace_content` estesa con due indici GIN in più, verificata su Postgres
  locale (RLS isolation confermata, pending correttamente escluse).
- **chat (Liste/checklist)** (Slice C del piano originale, mai realizzata finora — richiesta
  esplicita dell'utente) — scrivere in Chat "aggiungi alla lista spesa: latte, pane" crea una
  `Task` per elemento nella sezione Attività (tool `manage_tasks` in `ai-chat`, stesso pattern di
  `create_reminder`: nessuno stato pending/confirmed, reversibile con un tocco). Nessuna
  migrazione: le colonne (`generated_by_ai`, `chat_id`) esistevano già dalla slice Note/Task
  originale.
- **transaction (export riepilogo)** (richiesta esplicita dell'utente) — un pulsante "Condividi
  riepilogo" nel Bilancio globale apre un foglio con saldo/entrate/uscite/categorie in testo,
  con "Copia negli appunti" e "Invia via email" (`mailto:`, `url_launcher` già una dipendenza).
  Niente vero PDF: `pdf`/`printing`/`share_plus` sono pacchetti pub.dev nuovi che questo sandbox
  non può installare/verificare (pub.dev non è nella lista degli host raggiungibili dal proxy).
- **note (tag visibili)** (richiesta esplicita dell'utente) — `Note.tags` esisteva già nel
  dominio/nel repository ma nessuna schermata lo esponeva. Ora il form Nota ha un chip-input per
  aggiungere/rimuovere tag, l'anteprima li mostra come pillole, e una striscia di `FilterChip`
  sopra l'elenco filtra rapidamente per tag.
- **profile (tema)** (richiesta esplicita dell'utente: "tema chiaro/scuro") — uno
  `SegmentedButton` Sistema/Chiaro/Scuro; la preferenza (`AppThemeMode`) è salvata nei metadata di
  Supabase Auth (stesso meccanismo già usato per `name` alla registrazione), non una nuova
  tabella — si riflette in tutta l'app tramite `sessionControllerProvider`.

Strutturate e navigabili, in attesa delle rispettive fasi della roadmap
(`docs/product/26-execution-blueprint.md`):

- **profile** — identità account, logout e tema ora; abbonamento, memoria, privacy nelle fasi
  successive.

Non ancora presenti: memory, settings, billing.

## Limiti noti (dichiarati, non nascosti)

- Questo modulo non ha mai eseguito `flutter create` per le piattaforme native (`android/`,
  `ios/`): non esistono, quindi l'app non è ancora installabile su un device/emulatore reale.
  La piattaforma `web/` esiste (`flutter create --platforms=web .`, usata per generare una build
  dimostrativa) — `flutter build web` funziona, ma non è mai stata verificata con una chiamata
  reale a Supabase in questa sessione (restrizioni di rete dell'ambiente di sviluppo).
- `file_picker` (selezione file) e l'apertura effettiva di un URL con `url_launcher` non sono
  testabili in questo ambiente (nessun canale di piattaforma nativo): la logica di dominio e i
  repository sono comunque coperti da test con repository fake (`document_controller_test.dart`).
- La Chat non è stata verificata con una chiamata reale all'Edge Function `ai-chat` né al
  provider Anthropic (nessuna chiave disponibile in questa sessione, nessun `supabase start` con
  Docker): la logica applicativa (invio messaggio, stato di caricamento, propagazione errori) è
  coperta da test con repository fake (`chat_controller_test.dart`, `message_controller_test.dart`);
  l'Edge Function stessa è verificata solo staticamente (`deno check`/`lint`/`fmt`, vedi
  `infrastructure/supabase/README.md`).
- Lo stesso vale per il riconoscimento di spese/entrate in Chat (`extract_transactions`): la
  logica applicativa lato app è coperta da test con repository fake
  (`transaction_controller_test.dart`), ma se il modello riconosce correttamente le transazioni
  descritte in linguaggio naturale non è verificabile senza una chiamata reale ad Anthropic.
- Lo stesso per le foto nei messaggi: la logica applicativa (upload, invio dell'id come allegato,
  rendering della bolla) è verificata; se Claude interpreta correttamente l'immagine non è
  verificabile senza chiave reale. Solo JPEG/PNG/GIF/WebP sono garantiti compatibili — formati
  come HEIC (comune su iPhone) possono far fallire il turno con un errore generico, non un crash.
- Lo stesso per i due nuovi tool di sola lettura `query_balance_summary`/`query_reminders`: la
  logica di aggregazione (esclusione del Bilancio condiviso, filtro periodo) è stata verificata
  con `tsc --strict` (compilatore TypeScript reale, con shim locali per gli import `npm:`/i
  globali `Deno.*` — un livello di verifica più solido della sola rilettura manuale usata nelle
  slice precedenti), ma se il modello sceglie lo strumento giusto e il secondo giro con Anthropic
  produce una risposta pertinente non è verificabile senza una chiamata reale.
- Le notifiche push (`features/notifications`) hanno una parte web-only (`dart:js_interop` +
  `package:web`, isolata da import condizionale) non eseguibile in `flutter test` (nessun browser
  nel test runner): verificata con `flutter analyze` e un vero `flutter build web` con dart2js
  (compilazione reale contro le API di `package:web`, non solo analisi statica VM); la logica pura
  (codifica/decodifica delle chiavi Web Push) e la logica applicativa (controller) sono invece
  testate normalmente. Il comportamento a runtime — permesso richiesto, notifica effettivamente
  recapitata — non è verificabile senza un browser reale: su iPhone funziona solo dopo aver
  aggiunto il sito alla schermata Home (icona Condividi → Aggiungi a Home, richiede iOS 16.4+),
  mai da una scheda Safari normale.
- **Nessuna migrazione/Edge Function di questo progetto è mai stata applicata a un progetto
  Supabase reale da questa sessione**: serve un token di accesso Supabase (`supabase login`) che
  non è mai stato disponibile qui. Ogni `infrastructure/supabase/migrations/*.sql` scritto va
  eseguito manualmente (`npx supabase link` + `npx supabase db push`, vedi
  `infrastructure/supabase/README.md`) contro il progetto reale prima che il codice che lo
  presuppone funzioni in produzione — un gap tra "scritto nel repo" e "applicato al database" ha
  già causato un fallimento reale in produzione (salvataggio di una Transazione dopo la slice 7C,
  prima che la colonna `category` fosse effettivamente pushata).
- **Bilancio condiviso**: il codice d'invito va condiviso manualmente dall'utente (messaggio,
  chiamata, ecc.) — nessuna infrastruttura email/deep-link in questa slice. La migrazione
  `20260721160000_workspace_sharing.sql` (tabelle `workspace_members`/`workspace_invites`, RLS
  aggiuntive, funzione `redeem_workspace_invite`) va applicata manualmente al progetto Supabase
  reale come tutte le altre (vedi il punto sopra): senza di essa, creare un Bilancio condiviso o
  redimere un codice fallirà con un errore lato Supabase (tabella/funzione inesistente).
- **Promemoria via Chat**: come per il Bilancio condiviso, la migrazione
  `20260722090000_calendar_events.sql` va applicata manualmente al progetto Supabase reale prima
  che la funzionalità sia utilizzabile. In più, l'invio effettivo delle notifiche richiede un passo
  manuale aggiuntivo mai necessario prima in questo progetto: abilitare le estensioni `pg_cron`/
  `pg_net` (Database → Extensions nel pannello Supabase, non attive di default) ed eseguire il
  comando `cron.schedule` commentato in fondo alla migrazione, sostituendo `<PROJECT_REF>` e
  `<SERVICE_ROLE_KEY>` con i valori reali del progetto. Senza questo passo i promemoria vengono
  comunque creati e mostrati in app, ma la notifica push non parte mai. Nessun `pg_cron`/`pg_net`
  disponibili su Postgres locale (estensioni specifiche di Supabase, non del Postgres open source):
  verificata solo la RLS di `calendar_events`, non il comportamento del cron in sé.
- `google_fonts` (Manrope, redesign estetico) scarica il font a runtime da fonts.gstatic.com: in
  `flutter test` questo viene evitato del tutto (`isRunningInFlutterTest`, in
  `packages/design-system/lib/src/testing/`) perché in questa sandbox quel dominio non è
  raggiungibile — non accade in produzione (web o mobile), dove il fetch avviene nel browser/app
  dell'utente finale con rete normale, non nell'ambiente di sviluppo.
- **Build web: usare `--web-renderer html`** (bug segnalato dall'utente: "vorrei emoji colorate
  nella chat"). Il renderer di default (`auto`) usa CanvasKit su desktop, che non renderizza le
  emoji a colori — una limitazione nota di Flutter Web/Skia, non del codice di questo progetto:
  CanvasKit non recupera i font emoji a colori del sistema operativo nello stesso modo del
  renderer HTML, che invece usa il testo nativo del browser. `flutter build web --web-renderer
  html` risolve; nessun cambiamento di codice necessario.

## Setup locale

```
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=<url progetto> \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

Schema database e policy RLS: vedi `infrastructure/supabase/`.

## Test

```
flutter test
```
