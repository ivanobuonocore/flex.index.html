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
- **chat (chip di suggerimento)** (richiesta esplicita dell'utente, poi **rimossa** — vedi il punto
  più sotto) — tre `ActionChip` sopra il campo di testo ("Chiedi il saldo", "Ricorda che...",
  "Aggiungi alla lista"): scrivevano il testo nel campo (non inviavano subito, i due prefissi
  andavano completati) e sparivano appena l'utente iniziava a scrivere.
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
  d'invito da condividere, oppure unisciti a uno con un codice ricevuto. La condivisione riguardava
  inizialmente **solo le Transazioni** (poi estesa a Note/Attività, vedi sotto) — i Documenti
  restano visibili solo al proprietario, anche per un Workspace di cui qualcun altro è membro. Il
  Bilancio globale (`/balance`) esclude i Bilanci condivisi dal totale aggregato: restano due
  Bilanci separati, mai mescolati. Nuove tabelle `workspace_members`/`workspace_invites` e funzione
  `redeem_workspace_invite` (SECURITY DEFINER) — vedi `docs/database/README.md` per il dettaglio
  delle RLS (additive, non una riscrittura di quelle esistenti) e due bug reali trovati e corretti
  verificando su Postgres locale con due utenti simulati (ricorsione infinita tra le RLS di
  `workspaces`/`workspace_members`, colonna ambigua nella funzione di redeem).
- **note/task (Note/Attività condivise)** (richiesta esplicita dell'utente: estendere la
  condivisione oltre il Bilancio) — stesso meccanismo `workspace_members` sopra, esteso con policy
  RLS additive `notes_*_member`/`tasks_*_member` (select/insert/update/delete). Nessun codice
  mobile nuovo: `WorkspaceDetailScreen`/`NoteListScreen`/`TaskListScreen` sono già generiche per
  qualunque Workspace, quindi mostrano automaticamente le righe ora visibili a un membro grazie
  alla RLS — solo il testo del foglio "Bilancio condiviso creato!" è stato aggiornato per avvisare
  che ora si condividono anche Note e Attività. Documenti restano esclusi.

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
- **chat (Conferma/Scarta inline)** (richiesta esplicita dell'utente: "azioni rapide sulle
  transazioni pending direttamente in chat") — `messages.pending_transaction_ids` collega la
  risposta dell'assistente alle Transazioni pending che ha generato: la Chat mostra due pulsanti
  (Conferma/Scarta) subito sotto il messaggio, riusando `transactionFormControllerProvider` già
  esistente, senza dover aprire il Bilancio. Un id già deciso altrove (Bilancio o qui) smette
  semplicemente di comparire, filtrato per `status == pending` a ogni lettura.
- **reminder (promemoria ricorrenti)** (richiesta esplicita dell'utente) — `create_reminder`
  accetta un campo `recurrence` (`daily`/`weekly`/`monthly`, es. "ricordami ogni lunedì di
  buttare la spazzatura"): `ai-chat` genera automaticamente le occorrenze successive (numero
  fisso per frequenza, non deciso dal modello), condividendo un `recurrenceGroupId` — mostrato
  come una piccola icona "ricorrente" nell'elenco Appuntamenti. Ogni occorrenza resta una riga
  indipendente ed eliminabile singolarmente (nessuna "elimina tutta la serie" in questa slice).
  Nessuna modifica a `send-due-reminders`/`pg_cron`, già configurati: continuano a vedere righe
  indipendenti come sempre.
- **reminder (eliminare l'intera serie)** (richiesta esplicita dell'utente) — lo swipe su un
  promemoria ricorrente chiede prima "Solo questa occorrenza" o "Intera serie" invece di
  cancellare subito; un promemoria singolo resta immediato come sempre.
- **budget (per categoria)** (richiesta esplicita dell'utente) — legato all'utente, non a un
  Workspace: nuova sezione nel Bilancio con una barra di avanzamento per categoria (spesa del
  mese/limite), rossa e "Budget superato" oltre il 100%. Nascosta se non è stato impostato alcun
  budget.
- **transaction (spese ricorrenti automatiche)** (richiesta esplicita dell'utente) — scritte solo
  dall'AI in Chat ("il canone Netflix è 15,99€ ogni mese"); a differenza dei Promemoria ricorrenti,
  genera una Transaction pending alla volta, solo quando dovuta (Edge Function
  `create-due-recurring-transactions`, cron giornaliero), non tutte insieme in anticipo. Icona
  "Ricorrenti" nell'AppBar del Bilancio per consultare/cancellare i modelli.
- **transaction (scontrino allegato)** (richiesta esplicita dell'utente) — un Document persistente
  collegato alla Transazione (diverso dalla foto temporanea letta dall'AI per estrarne l'importo),
  gestito dal form di modifica: allega/apri/rimuovi. Icona scontrino nell'elenco quando presente.
- **transaction (andamento multi-mese + confronto mese precedente)** (richiesta esplicita
  dell'utente) — nell'hero del saldo, un badge "vs mese scorso" (percentuale di variazione rispetto
  al mese precedente quello selezionato nella tendina; nascosto se il mese precedente ha saldo 0,
  nessun confronto sensato). Sotto il grafico a torta, un grafico a barre `fl_chart` con gli ultimi
  6 mesi (entrate/uscite confermate affiancate), calcolato sullo stesso mese di riferimento della
  tendina. Logica pura in `transaction_controller.dart` (`percentChange`, `lastMonths`,
  `monthlyTotals`), nessuna nuova tabella: aggrega le stesse transazioni già caricate.
- **memory (prima slice minima)** (richiesta esplicita dell'utente) — solo il livello Globale:
  l'AI salva una nota quando l'utente dice esplicitamente "ricorda che..." (tool `remember_fact`,
  sempre disponibile come le query di sola lettura), e le memorie salvate vengono iniettate nel
  system prompt di ogni turno futuro perché l'AI possa davvero usarle, non solo scriverle.
  `MemoryListScreen` (Profilo → "Memoria") mostra e permette di cancellare, nessuna creazione
  manuale — coerente con `MemoryRepository`, che non espone alcun metodo di creazione.
- **memory (livello Workspace)** (richiesta esplicita dell'utente) — a differenza del Globale,
  creata manualmente ("Chat unica" non sa a quale Workspace collegare un ricordo pronunciato al
  suo interno). `WorkspaceMemoryListScreen` (`/workspace/:id/memories`, anche in anteprima nella
  Home del Workspace), FAB con un dialog minimale per aggiungerla, conferma via dialog prima di
  cancellare su swipe. Livello Conversazione fuori scope: con un'unica conversazione per utente
  coinciderebbe sempre col Globale.
- **conferma su swipe-to-delete** (richiesta esplicita dell'utente: "conferma su swipe-to-delete
  per elementi non banali") — Note, Attività, Documenti e Memoria globale ora chiedono conferma con
  un `AlertDialog` prima di cancellare (già presente per Memoria di Workspace, Promemoria ricorrenti
  e spese ricorrenti dalle slice precedenti). Bug reale trovato in `DocumentListScreen`: la
  schermata osserva `documentFormControllerProvider` per lo spinner di upload sul FAB, ma `delete()`
  usa lo stesso controller — il giro `AsyncLoading`→`AsyncData` di un'eliminazione ricostruiva la
  lista mentre il `Dismissible` era ancora a metà dell'animazione di uscita, reinserendo la stessa
  riga prima che il repository l'avesse rimossa ("A dismissed Dismissible widget is still part of
  the tree", riprodotto deterministicamente da un test widget). Corretto con una rimozione
  ottimistica locale (`Set<String>` di id appena scorsi, filtrati dalla lista finché il repository
  non conferma).
- **badge su Appuntamenti e sul pulsante Chat** (richiesta esplicita dell'utente: "badge sulla tab
  Appuntamenti/Chat") — adattato alla navigazione reale del progetto (5 tab: Spazi/Bilancio/Chat
  centrale/Ricerca/Profilo, Appuntamenti è una sezione fissa, non una tab a sé). Il chip
  "Appuntamenti" nella striscia "Sezioni" in Chat mostra un badge col numero di promemoria di oggi
  (`remindersDueToday`, in `section_preview.dart` — anche l'anteprima testuale era ancora ferma al
  placeholder "Presto disponibile" di prima che i Promemoria esistessero, corretta insieme).
  Il pulsante Chat centrale mostra un badge con le transazioni suggerite dall'AI ancora da
  confermare/scartare (`pendingTransactions`, già esistente) — non un concetto di "messaggio non
  letto", che non esiste dato che la Chat è sempre la Home.
- **skeleton loading nelle liste** (richiesta esplicita dell'utente) — nuovo `SkeletonList`
  (`shared/widgets/`, righe pulsanti al posto dello spinner centrato) al posto di `LoadingView` in
  Note, Attività, Documenti, Bilancio (globale e per Workspace) e Appuntamenti — le schermate a
  lista, dove uno spinner dice meno della forma stessa del contenuto in arrivo. Animazione
  indeterminata (si ripete finché il widget è a schermo, come un `CircularProgressIndicator`): nei
  test va verificata con `pump()` a durata limitata, non `pumpAndSettle()` — stessa lezione già
  imparata altrove in questo progetto.
- **empty state illustrati** (richiesta esplicita dell'utente) — `EmptyState` (shared/widgets/) ha
  ora un'icona più grande su un doppio cerchio sfumato ("illustrazione", stesso trattamento
  gradiente/glow già usato per hero del saldo e striscia Sezioni) invece della singola icona grigia
  di prima, con un parametro `color` opzionale per intonare la tinta alla sezione (Bilancio, Note,
  Attività, Documenti, Appuntamenti — le stesse tinte già usate per badge di categoria e Sezioni).
  Nessuna dipendenza nuova: solo widget, nessuna immagine/asset.
- **export (dati completi)** (richiesta esplicita dell'utente) — Profilo → "Esporta i miei dati":
  un JSON con Note/Attività/Documenti (solo metadata, non i file)/Promemoria/Memoria di ogni
  Workspace, più Transazioni e Memoria globale. Lettura one-shot (`.first` su ogni stream, non
  realtime: un export è uno snapshot). `DataExportController` (`AutoDisposeAsyncNotifier<String?>`)
  avvia `generate()` dal proprio `initState()`, non dal chiamante che apre il foglio: tra
  l'apertura di `showModalBottomSheet` e il montaggio effettivo del foglio passano più frame senza
  alcun ascoltatore del provider, e un provider `autoDispose` verrebbe ricreato da zero in quella
  finestra, perdendo il risultato. Stesso limite dichiarato per l'export del Bilancio: niente
  PDF/file scaricabile (pacchetti non disponibili), solo copia negli appunti e invio via email.

Strutturate e navigabili, in attesa delle rispettive fasi della roadmap
(`docs/product/26-execution-blueprint.md`):

- **onboarding leggero al primo accesso** (richiesta esplicita dell'utente) — nuova
  `OnboardingScreen` (`/onboarding`), 3 schermate scorrevoli (`PageView`) sui pilastri dell'app
  (Chat, Spazi, Memoria/conferma esplicita) con un pulsante "Salta" sempre visibile e "Inizia"
  solo sull'ultima. `User.onboardingCompleted` (default `false`, persistito lato identity
  provider come la preferenza di tema — nessuna nuova tabella) aggiunge un gate al redirect di
  GoRouter: un utente autenticato che non l'ha ancora completato viene sempre indirizzato lì
  prima di `/chat`, mai più dopo averla completata o saltata.
- **profile** — identità account, logout, tema e Memoria ora; abbonamento e privacy nelle fasi
  successive.

Non ancora presenti: settings, billing.

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
- Lo stesso per il banner di installazione PWA (`features/pwa_install`): la parte web-only è
  verificata con `flutter analyze` e un vero `flutter build web` con dart2js, ma l'evento
  `beforeinstallprompt` non è simulabile in `flutter test` — se e quando il browser lo emette
  davvero (Chrome/Edge desktop e Android; mai su iOS Safari, che non lo supporta affatto) va
  verificato manualmente. La disponibilità del prompt è comunque un provider runtime testabile con
  un fake (`FakeInstallPromptService`), a differenza delle notifiche push che restano gated da una
  costante di compilazione mai vera nei test.
- **Markdown "lite" nelle risposte dell'assistente** (richiesta esplicita dell'utente, "anche solo
  migliorie grafiche") — nuovo `features/chat/application/markdown_lite.dart`: parser scritto a
  mano (regex, solo grassetto `**testo**` ed elenchi puntati con `- ` a inizio riga), non un
  pacchetto (`flutter_markdown` non era tra le dipendenze e comprerebbe robustezza — link,
  escaping, codice inline — non necessaria per messaggi di chat brevi, al costo di una dipendenza
  in più). `containsMarkdownLite`/`parseMarkdownLite` sono funzioni pure, testabili senza Flutter
  widget bindings. In `_MessageBubble` (`chat_home_screen.dart`), il nuovo widget `_MessageText`
  resta un `Text` semplice quando il contenuto non ha alcun marcatore — il caso comune, incluso
  ogni messaggio dell'utente e ogni fixture di test esistente — e diventa un `Text.rich` solo
  quando li contiene davvero: `find.text(...)` (usato in tutta `chat_home_screen_test.dart`)
  ignora `RichText`/`Text.rich` per difetto, quindi passare sempre a `Text.rich` avrebbe rotto
  ogni asserzione esistente. Stile del grassetto: `fontWeight: FontWeight.w700` sul `TextSpan`
  figlio (eredita colore/dimensione dallo stile di base impostato sul `TextSpan` padre). Il system
  prompt (`ASSISTANT_PERSONA`, `ai-chat/index.ts`) guadagna un paragrafo che dice esplicitamente al
  modello che grassetto ed elenchi puntati sono ora resi correttamente e possono essere usati con
  moderazione — senza questo, il modello non avrebbe motivo di produrre quella sintassi. **Nota
  tecnica sul test**: `Text.rich(mySpan)` avvolge `mySpan` come unico figlio di un `TextSpan`
  esterno (quello che porta lo stile ereditato da `DefaultTextStyle`) — il test widget che verifica
  lo stile del frammento in grassetto deve quindi scendere di un livello (`richText.text.children!
  .single`) prima di ispezionare i figli reali prodotti da `_MessageText`, non `richText.text`
  direttamente.
- **Nessuna migrazione/Edge Function di questo progetto è mai stata applicata a un progetto
  Supabase reale da questa sessione**: serve un token di accesso Supabase (`supabase login`) che
  non è mai stato disponibile qui. Ogni `infrastructure/supabase/migrations/*.sql` scritto va
  eseguito manualmente (`npx supabase link` + `npx supabase db push`, vedi
  `infrastructure/supabase/README.md`) contro il progetto reale prima che il codice che lo
  presuppone funzioni in produzione — un gap tra "scritto nel repo" e "applicato al database" ha
  già causato un fallimento reale in produzione (salvataggio di una Transazione dopo la slice 7C,
  prima che la colonna `category` fosse effettivamente pushata).
- **Fix**: bug segnalato dall'utente ("la chat non va, mi esce scritto il messaggio [che non è
  stato possibile caricare i messaggi]") — stesso gap operativo del punto sopra, questa volta su
  `messages.pending_transaction_ids` (colonna aggiunta dalla migrazione della slice "Conferma/
  Scarta inline", più recente di `attachment_ids`/`source_references`): se non ancora pushata su
  un progetto reale, la colonna esiste come `null` nella riga (non assente), e il cast diretto
  (`as List<dynamic>`) in `SupabaseMessageRepository._toDomain` esplodeva dentro il `.map()` dello
  stream realtime — l'intera Chat mostrava "Non è stato possibile caricare i messaggi." per un
  problema di migrazione mancante, non un errore di rete o RLS reale. Corretto rendendo il parsing
  di tutte e tre le colonne array tollerante a `null` (lista vuota, non un'eccezione) ed estraendolo
  in una funzione pura `parseMessageRow` (stesso motivo di `parseReceiptExtractionResponse`:
  testabile senza mockare Supabase) — la Chat carica sempre i messaggi esistenti anche prima che
  quella specifica migrazione sia stata applicata, semplicemente senza i chip Conferma/Scarta
  inline finché non lo è.
- **Fix**: stesso gap operativo, stavolta sul Bilancio ("non è stato possibile caricare il
  bilancio" dopo aver ripubblicato il sito con tutte le 8 integrazioni) — audit sistematico di ogni
  colonna aggiunta da una migrazione additiva di questa sessione e letta con un cast diretto
  (non nullable) lato client, per evitare di scoprirle una alla volta a ogni nuova segnalazione.
  Trovate e corrette tre in più: `transactions.tags`/`documents.tags` (Slice 1, in
  `parseTransactionRow`/`parseDocumentRow`, ex `_toDomain`) e `workspace_members.role`/
  `workspace_invites.role` (Slice 3, in `parseWorkspaceMemberRow`/`parseWorkspaceInviteRow`, ex
  `_memberFromDb`/`_inviteFromDb`) — tutte estratte in funzioni pure top-level e rese tolleranti a
  `null` (lista vuota per i tag, `WorkspaceRole.editor` per il ruolo — lo stesso default della
  colonna SQL), stesso principio del fix sopra. Verificate anche `calendar_events.google_event_id`
  (già `String?`, sicura) e le colonne di `category_budgets` aggiunte per gli avvisi budget (mai
  lette dal client, solo dalla Edge Function — sicure); non toccata `notes.tags`, presente fin
  dalla migrazione originale delle Note (non una aggiunta di questa sessione, nessuna segnalazione
  di rottura). **Resta comunque necessario** applicare le migrazioni mancanti con `npx supabase db
  push`: questi fix evitano il crash e degradano (niente tag/ruoli differenziati finché lo schema
  reale non è allineato), non sostituiscono la migrazione reale.
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
- **Bilancio: pulsante "Categorie di spesa" con la somma totale visibile** (richiesta esplicita
  dell'utente: "vorrei si potesse vedere magari con un tasto la somma di tutte le categorie di
  spese fatte") — prima l'unico modo per vedere il dettaglio per categoria delle Uscite era
  toccare la pillola "Uscite" dell'hero (un gesto poco scopribile, non sembra un pulsante); ora un
  `OutlinedButton` esplicito sotto l'hero apre lo stesso `showModalBottomSheet`
  (`_showCategoryBreakdown`, riusato senza modifiche alla logica). Lo sheet mostra anche la somma
  di tutte le categorie in testa ("Totale: ..."), prima calcolata solo per le percentuali e mai
  mostrata come testo. Le categorie di spesa esistevano già (`TransactionCategory`, Fase 3 slice
  7C) — nessuna nuova categoria da generare, solo questa mancanza di visibilità da correggere. La
  Chat sa già rispondere a "quanto ho speso questo mese" e "quanto ho speso in <categoria>" tramite
  lo strumento `query_balance_summary` dell'Edge Function `ai-chat` (vedi sezione Edge Function più
  sotto) — nessun cambiamento necessario lì.
- **Tag su Transazioni e Documenti** (integrazione richiesta esplicitamente, prima di una serie di
  altre) — stesso pattern già usato per le Note: `create_edit_transaction_sheet.dart` guadagna lo
  stesso campo chip-input della sheet Nota, e il Bilancio mostra le pillole dei tag sotto ogni
  transazione confermata. I Documenti non hanno un form di modifica generico (nome e file restano
  immutabili dopo il caricamento): un nuovo pulsante "Modifica tag" per riga apre un piccolo foglio
  dedicato (`_EditTagsSheet`), e `document_list_screen.dart` guadagna la stessa striscia di filtro
  rapido per tag già presente nelle Note. `DocumentRepository.updateTags` è l'unico modo per
  cambiare un Document dopo la creazione — non un `copyWith` generico, che non avrebbe senso dato
  che gli altri campi sono immutabili. Mai popolati dall'AI Engine: `extract_transactions` in
  `ai-chat` resta invariato.
- **Previsione di fine mese nel Bilancio** (integrazione richiesta esplicitamente) — nuova
  funzione pura `projectedMonthEndExpenseCents` in `transaction_controller.dart`: estrapolazione
  lineare della spesa già sostenuta sui giorni restanti del mese (non un modello predittivo), `null`
  il primo giorno del mese (nessuna proiezione sensata da un solo giorno di dati). Una nuova card
  compare tra l'hero e il grafico a torta, solo quando il mese selezionato nella tendina è quello
  corrente — su uno storico non avrebbe senso, ed è il chiamante (`BalanceOverviewScreen`) a
  garantirlo, non la funzione pura.
- **Permessi granulari (viewer/editor) sui Workspace condivisi** (integrazione richiesta
  esplicitamente) — fin dalla prima slice di "Bilancio condiviso" ogni membro aveva sempre gli
  stessi diritti del proprietario; ora il proprietario sceglie, sia creando il Bilancio condiviso
  sia generando un nuovo codice d'invito (`shared_balance_screen.dart`, `SegmentedButton`
  "Modificare"/"Solo leggere"), se chi si unisce potrà scrivere o solo leggere — e può cambiare il
  ruolo di un membro già presente in qualsiasi momento (`DropdownButton` per riga nel foglio
  "Gestisci membri"). Nuovo `WorkspaceRole` (`viewer`/`editor`, default `editor` per non cambiare
  il comportamento di prima) in `packages/domain`; `currentMemberRoleProvider(workspaceId)`
  (`workspace_sharing_controller.dart`) riusa `workspaceMembersProvider` invece di una query
  dedicata — sotto RLS un membro (non il proprietario) vede sempre e solo la propria riga in
  `workspace_members`, quindi la sua presenza/ruolo *è già* la risposta a "che ruolo ho qui".
  `transaction_report_screen.dart`, `note_list_screen.dart` e `task_list_screen.dart` nascondono
  FAB, swipe-to-delete e il tocco-per-modificare quando il ruolo è `viewer` — l'applicazione
  effettiva dei permessi resta comunque la RLS lato Supabase (`docs/database/README.md`, slice
  27), la UI qui è solo coerenza percepita, non l'unica barriera.
- **Notifica push su budget quasi superato** (integrazione richiesta esplicitamente) — finora
  "budget superato" era solo un colore nella `_BudgetTile` del Bilancio, senza avviso attivo. Ora,
  subito dopo che una spesa viene creata o confermata (`TransactionFormController._maybeAlertBudget`
  in `transaction_controller.dart`), se la categoria ha un budget impostato e la spesa
  già confermata questo mese più quella appena creata/confermata supera l'80% o il 100% del limite,
  una chiamata diretta (stesso pattern di `send-test-push`, non un cron) alla nuova Edge Function
  `send-budget-alert` invia la notifica. Interamente best-effort: nessun errore qui (provider non
  ancora popolati, funzione non deployata) blocca mai il successo di create/confirm già ritornato
  all'utente — stesso principio già usato per l'allegato scontrino. La soglia non viene rinotificata
  più volte nello stesso mese: `category_budgets.last_alert_threshold`/`last_alert_month`
  (nuova migrazione), scritti solo dalla Edge Function, mai dal client. I Budget restano valutati
  solo sui Workspace personali (stesso aggregato di `_BudgetSection`): una spesa in un Bilancio
  condiviso non innesca mai una notifica. **Limite noto**: lo speso del mese è letto da
  `transactionsProvider(null)`/`budgetsProvider`/`workspacesProvider` con un `ref.read` non
  garantito "caldo" — se nessuna schermata li ha ancora sottoscritti in questa sessione (es. la
  primissima spesa creata subito dopo l'avvio, prima di aver mai aperto il Bilancio), l'avviso
  può essere saltato silenziosamente quella volta; nessun impatto sulla correttezza del saldo, solo
  sulla tempestività della notifica.
- **OCR sugli scontrini allegati manualmente** (integrazione richiesta esplicitamente) — finora
  "Allega scontrino" (`create_edit_transaction_sheet.dart`, solo in modifica: serve l'id della
  Transazione già salvata) era un allegato statico, nessuna lettura del contenuto. Riusa la stessa
  pipeline vision già usata da `ai-chat` per le foto allegate in Chat (`fetchImageBlock`), non un
  secondo servizio OCR esterno (coerente con "mai un secondo provider AI diretto dal frontend"):
  subito dopo l'upload+attach, `_prefillFromReceipt` chiama `TransactionRepository.
  extractReceiptData` (nuovo metodo — Edge Function `ai-chat` in una modalità isolata,
  `extractReceiptDocumentId`, nessun messaggio di Chat creato, tool `extract_transactions` forzato
  invece di lasciato "auto") e, se torna un risultato, precompila descrizione/importo/categoria nel
  form — l'utente resta libero di correggerli prima di toccare "Salva" ("l'AI suggerisce, l'utente
  decide", stesso principio già applicato al resto dell'AI Engine). Se la lettura fallisce o la
  foto non è leggibile come scontrino, il form resta com'era: nessun errore bloccante, stesso
  principio già usato per la notifica budget. `parseReceiptExtractionResponse` (funzione pura in
  `supabase_transaction_repository.dart`) isola la conversione della risposta JSON in un
  `ReceiptExtraction`, testabile senza mockare il client Supabase.
- **Dettatura vocale in Chat** (integrazione richiesta esplicitamente) — nuovo pulsante microfono in
  `_MessageInput` (`chat_home_screen.dart`, tra il bottone foto e il campo testo), visibile solo se
  `SpeechToText.initialize()` ha successo: niente bottone che poi fallisce silenzioso al tocco
  (rischio esplicito: il supporto varia per browser, buono su Chrome/Edge, spesso assente su
  Safari). Mentre ascolta, il testo trascritto sostituisce in tempo reale il contenuto del campo —
  l'utente vede e può correggere prima di inviare ("l'AI suggerisce, l'utente decide", stesso
  principio già applicato al resto della Chat). Un solo package (`speech_to_text`, non due
  implementazioni separate come inizialmente previsto — vedi `docs/database/README.md`, slice 30,
  per il motivo): il plugin risolve da sé l'implementazione per piattaforma, canale nativo su
  mobile/desktop oppure il Web Speech API su web tramite il proprio plugin federato
  (`speech_to_text_web`, già basato su `package:web`), nessun ramo `kIsWeb` scritto a mano in questo
  progetto. Un errore di `initialize()`/`listen()` (piattaforma senza plugin registrato o senza
  supporto) equivale semplicemente a "non disponibile", mai un crash. **Nota sulle piattaforme**:
  questo repository non ha ancora cartelle `android/`/`ios/` (solo `web/`), quindi il permesso
  microfono a runtime (`AndroidManifest.xml`/`Info.plist`) non è ancora applicabile — da aggiungere
  quando quei target verranno generati con `flutter create`.
- **Sync con Google Calendar** (integrazione richiesta esplicitamente) — nuova card "Google
  Calendar" in Profilo (`profile_screen.dart`), nascosta finché l'app non è compilata con
  `--dart-define=GOOGLE_CALENDAR_ENABLED=true` (`AppEnv.googleCalendarEnabled`, stesso principio di
  gating già usato per `AppEnv.vapidPublicKey`/notifiche — qui però non serve alcun valore al
  client, solo un interruttore: nessun segreto Google finisce mai nel bundle dell'app). Il
  collegamento riusa `supabase_flutter`'s `auth.linkIdentity(OAuthProvider.google, scopes:
  'https://www.googleapis.com/auth/calendar.events')` — mai un flusso OAuth scritto a mano, mai il
  frontend collegato direttamente a Google (CLAUDE.md, esteso per analogia a qualsiasi provider
  terzo): Supabase gestisce il redirect e lo scambio codice/token, il client non vede mai il
  client secret. `SupabaseCalendarSyncRepository` ascolta `auth.onAuthStateChange` fin dalla
  costruzione perché Supabase espone `session.providerRefreshToken` solo nel primo evento subito
  dopo un collegamento riuscito, mai persistito — lo invia una sola volta alla nuova Edge Function
  `save-calendar-connection`, che lo salva sotto RLS in `calendar_connections`.

  Il refresh token non è mai letto dal client mobile: lo stato "connesso/non connesso" mostrato in
  Profilo passa da `get_my_calendar_connection()` (funzione Postgres `security definer` che
  restituisce solo i campi non sensibili — vedi la migrazione), non da uno `.stream()` realtime
  come le altre entità dell'app (un `postgres_changes` realtime invierebbe l'intera riga, token
  incluso, ad ogni aggiornamento). `CalendarEventRepository.syncToGoogleCalendar` (chiamata da
  `CalendarEventFormController.create`/`delete`, stesso principio best-effort di
  `BudgetRepository.checkBudgetAlert`) invoca la nuova Edge Function `sync-calendar-event` per
  creare/cancellare il gemello Google di un Promemoria; `pull-google-calendar-events` (cron,
  service role, stesso pattern di `send-due-reminders`) importa in senso opposto gli eventi
  creati/modificati direttamente su Google. **Limite noto**: `deleteSeries` (cancellare un'intera
  serie ricorrente) non sincronizza oggi la cancellazione con Google — richiederebbe di risalire a
  ogni singolo id della serie, fuori scopo per questa integrazione.
- **Migliorie grafiche: redesign estetico 2.0 esteso a tutte le schermate** (richiesta esplicita
  dell'utente) — Chat Home, Bilancio (globale e di Workspace) e Onboarding avevano già il
  gradiente `AppColors.heroGradient`/`AppShadows.glow`/`AppRadii.cardPremiumRadius`; le schermate
  rimaste "Material piatto" lo riusano ora (nessun nuovo token, solo applicazione dei widget già
  esistenti): `GradientAppBar` al posto di `AppBar` in Note/Attività/Documenti/Ricerca/
  Spazi/Bilancio condiviso/Bilancio di Workspace/Appuntamenti; `SkeletonList` al posto di
  `LoadingView` in Spazi e Bilancio condiviso (unica coppia di liste principali rimasta sul vecchio
  spinner pieno, tutte le altre già migrate nella slice #112). `transaction_report_screen.dart`
  (Bilancio di un singolo Workspace) guadagna lo stesso trattamento "hero" già usato dal Bilancio
  globale (`_BalanceHeroCard` locale al file, saldo su gradiente + pillole Entrate/Uscite
  traslucide): prima le due schermate di Bilancio erano visivamente incoerenti tra loro. In
  Profilo, l'header con nome/email/avatar è ora un riquadro con lo stesso gradiente hero e
  l'avatar ha `AppShadows.glow` — prima un `CircleAvatar` su sfondo piatto. **Scelta di scopo
  deliberata**: `search_screen.dart` usa ancora `LoadingView()` (non `SkeletonList`) — il pass
  grafico originale nominava esplicitamente solo Spazi e Bilancio condiviso per quel cambio,
  Ricerca ne era rimasta fuori anche se tecnicamente nella stessa condizione; corretto solo
  l'`AppBar`. Nessuna modifica di logica in questa slice: solo widget di presentazione, verificato
  che l'intera suite di test esistente (208 in `apps/mobile`, 40 in `packages/domain`) continuasse
  a passare invariata.
- **Chat: suggerimenti integrati nelle risposte invece di pulsanti fissi** (richiesta esplicita
  dell'utente: "non mi piacciono quei pulsanti... vorrei fossero integrate nelle risposte
  dell'assistente non come pulsanti sotto") — rimossi del tutto `_QuickSuggestionsRow`/
  `_QuickSuggestion`/`_applySuggestion` da `chat_home_screen.dart` (i tre `ActionChip` "Chiedi il
  saldo"/"Ricorda che..."/"Aggiungi alla lista" sopra il campo di testo, introdotti in una slice
  precedente): nessun elemento toccabile dedicato li sostituisce, per scelta esplicita dell'utente
  (opzione "solo testo naturale, nessun pulsante" tra quelle proposte). Il system prompt
  dell'Edge Function `ai-chat` (`ASSISTANT_PERSONA`) guadagna invece un paragrafo che invita
  l'assistente a proporre lui stesso, a parole e quando naturale nel contesto, le stesse tre azioni
  (es. "Vuoi che te lo ricordi?") — nessuna garanzia che compaia a ogni risposta (è una linea guida
  di stile, non un pulsante deterministico): coerente con "l'assistente è un collaboratore
  proattivo", non verificabile con un test automatico (dipende dal comportamento reale del
  modello). Rimosso anche l'unico test che assumeva i tre chip fissi
  (`chat_home_screen_test.dart`).
- **"Oggi" in Chat Home** (richiesta esplicita dell'utente, dopo aver confermato la scelta di
  arricchire la Chat Home esistente invece di una tab dedicata — `docs/product/
  06-information-architecture.md` aveva già scartato una tab "Today" separata in passato) — nuovo
  blocco `_TodayHighlights` in `chat_home_screen.dart`, sopra la striscia "Sezioni": prossimo
  impegno di oggi (`calendarEventsProvider` + `remindersDueToday`, già in
  `section_preview.dart`), attività aperte (`tasksProvider` + una nuova funzione pura
  `openTasks` in `task_controller.dart`, condivisa anche da `_AttivitaPreview` per non duplicare
  lo stesso filtro), proiezione di fine mese (`transactionsProvider` + `confirmedThisMonth`/
  `totalExpenseCents`/`projectedMonthEndExpenseCents`, già in `transaction_controller.dart`) —
  nessuna nuova query, solo provider già esistenti riletti nello stesso punto. Ogni riga compare
  solo se ha qualcosa da dire; se tutte e tre sono vuote il blocco non occupa spazio (stesso
  principio di `_NotificationStatusBanner`). Ogni riga è toccabile e porta alla schermata
  pertinente (`context.push`, stesso pattern già usato da `search_screen.dart` per le route
  annidate di un Workspace).
- **Knowledge Graph "lite"** (richiesta esplicita dell'utente, scope ridotto rispetto alla visione
  completa di `docs/product/19-knowledge-graph.md` — nessuna migrazione, nessun grafo/
  embeddings/vettori, solo collegamenti che esistono già nello schema e vengono già scritti oggi)
  — due superfici:
  - **Documenti → Transazioni**: nuovo provider derivato `linkedDocumentIdsProvider` in
    `document_controller.dart`, che osserva `transactionsProvider` (già la fonte di verità per
    `Transaction.documentId`) e ne deriva l'insieme dei documenti referenziati — nessuna nuova
    query. `document_list_screen.dart` mostra un badge "Collegato a una transazione" quando un
    documento è in quell'insieme.
  - **Promemoria creati dalla Chat**: `CalendarEvent.sourceChatId` è già scritto da
    `create_reminder` nell'Edge Function `ai-chat` — nessun nuovo provider, è un campo diretto
    sull'entità. `reminder_list_screen.dart` mostra un'icona "creato dalla Chat" accanto (non al
    posto) all'icona "ricorrente" già esistente.
  - **Contesto AI**: `buildSystemPrompt` (`ai-chat/index.ts`) amplia la `select` sui documenti per
    includere `chat_id` e annota "(allegato in una conversazione)" quando presente — coerente con
    `docs/product/13-prompt-engineering.md` ("documenti collegati").
  - **Esclusioni esplicite**: `Task.documentId`/`Task.chatId`/`CalendarEvent.sourceTaskId` esistono
    nel dominio ma non vengono mai scritti da nessun punto del codice attuale (verificato con
    grep mirato prima di implementare) — costruirci sopra UI oggi mostrerebbe sempre il caso
    vuoto, quindi esclusi da questa slice. Note non ha alcun campo di collegamento (richiederebbe
    una nuova migrazione) — esclusa per scelta esplicita dell'utente, per non ripetere il
    problema delle migrazioni non applicate avuto in questa stessa sessione.
  - **Bug scoperto e corretto durante l'implementazione**: `ref.watch(provider).value` su un
    `AsyncValue` in stato di errore **rilancia l'eccezione originale** invece di restituire
    `null` (a differenza di quanto usato altrove in buona fede in questa sessione) — un
    `calendarEventRepositoryProvider`/`transactionRepositoryProvider` non sovrascritto in un test,
    o un Workspace non ancora bootstrappato in produzione, faceva fallire l'intera Chat Home
    invece di limitarsi a non mostrare quella riga. Corretto usando `.asData?.value` (che invece
    ritorna `null` in modo sicuro su qualunque stato diverso da dati) sia in `_TodayHighlights` sia
    in `linkedDocumentIdsProvider` — scoperto grazie ai nuovi test widget di questa stessa slice,
    non in produzione.
- **Miniature immagine per i Documenti** (richiesta esplicita dell'utente, "anche solo migliorie
  grafiche") — estratto in un nuovo widget condiviso `shared/widgets/document_thumbnail.dart` il
  pattern già usato da `_AttachmentImage` in `chat_home_screen.dart` per gli allegati foto in Chat
  (`documentDownloadUrlProvider` + `Image.network` con stati di caricamento/errore), parametrizzato
  per dimensione. Riusato sia dalla Chat (che perde la sua versione locale duplicata) sia da
  `document_list_screen.dart`, dove un documento `image/*` mostra ora una vera miniatura 48×48 al
  posto dell'icona generica per tipo di file.
- **Andamento per categoria nel tempo nel Bilancio** (richiesta esplicita dell'utente) — il tocco
  su una categoria nel dettaglio Entrate/Uscite (`_CategoryBreakdownTile`, già raggiungibile dalle
  pillole dell'hero o dal pulsante "Categorie di spesa") apre un nuovo sheet con un grafico a barre
  dell'andamento di quella categoria negli ultimi 6 mesi. Nessuna nuova aggregazione: nuova funzione
  pura `categoryMonthlyTotals` in `transaction_controller.dart`, composizione di `lastMonths`/
  `confirmedThisMonth`/`amountCentsByCategory` già esistenti (richiede esplicitamente il tipo
  entrata/uscita, per non sommare per sbaglio import ed export della stessa categoria nello stesso
  mese). Il grafico (`_CategoryTrendChart`) riusa esattamente lo stile `BarChart` già stabilito da
  `_TrendChart`.
- **Pulsante "azione rapida" su un Workspace** (richiesta esplicita dell'utente) — nuovo
  `FloatingActionButton` in `workspace_detail_screen.dart` che apre un `showModalBottomSheet` con
  quattro `ListTile` (Nota/Attività/Transazione/Promemoria — i Documenti restano esclusi, si
  caricano con un file picker, non con una sheet di testo), ciascuno instrada alla sheet di
  creazione già esistente per quella entità. Gating: nascosto per un membro con ruolo `viewer`,
  stesso principio già applicato a ogni altro pulsante di creazione nei Workspace condivisi
  (`currentMemberRoleProvider`). **Bug scoperto e corretto in questa slice**: lo stesso
  `currentMemberRoleProvider` (`workspace_sharing_controller.dart`) leggeva `sessionControllerProvider`/
  `workspaceMembersProvider` con `.value` invece di `.asData?.value` — innocuo finché ogni schermata
  che lo usava veniva sempre montata con quei provider già sovrascritti nei test, ma il nuovo FAB fa
  sì che `WorkspaceDetailScreen` lo osservi incondizionatamente fin dalla prima build: un test senza
  quegli override (`workspace_navigation_test.dart`, preesistente) ha iniziato a far fallire l'intera
  schermata invece di limitarsi a trattare il ruolo come "nessuno". Stesso identico bug già
  documentato sopra per `_TodayHighlights`/`linkedDocumentIdsProvider`, stessa correzione.
- **Banner "Aggiungi alla schermata Home" (installazione PWA)** (richiesta esplicita dell'utente)
  — nuovo `features/pwa_install/`, stesso pattern a tre file già stabilito per
  `features/notifications/` (interfaccia `InstallPromptService` + `_stub.dart` + `_web.dart`,
  import condizionale `if (dart.library.js_interop)`). L'implementazione web ascolta l'evento
  browser `beforeinstallprompt` (proprietario di Chromium/Edge, non nello standard W3C — extension
  type minimo `_BeforeInstallPromptEvent` con solo `prompt()`, dato che non è nei binding generati
  di `package:web`), lo intercetta con `preventDefault()` per poterlo mostrare su richiesta invece
  che automaticamente, ed espone `promptInstall()`; l'evento standard `appinstalled` segna
  l'installazione avvenuta. Nuova card `_InstallAppCard` in `profile_screen.dart`, stesso stile di
  `_NotificationsCard`: nascosta del tutto finché `installAvailableProvider` non emette `true`
  (browser non Chromium/Edge, app già installata, o iOS Safari che non lo supporta affatto — copy
  coerente con quanto già scritto per le notifiche push su iOS). A differenza delle card
  Notifiche/Google Calendar (gated da una costante di compilazione mai vera nei test), qui la
  disponibilità è un provider runtime: **testabile per intero con un fake**
  (`FakeInstallPromptService`), non solo dichiarata non verificabile. **Non verificabile in questa
  sandbox**: solo il comportamento reale dell'evento nel browser (nessun browser nel test runner,
  `beforeinstallprompt` non è simulabile) — verificato che `flutter build web` compili
  correttamente la forma dell'interop, comportamento a runtime da verificare manualmente in
  Chrome/Edge, stesso limite già accettato per le notifiche push.
- **Rimosso il selettore emoji dalla Chat** (richiesta esplicita dell'utente: "elimina l'emoji
  accanto la tastiera perché non ha molto senso") — tolti il pulsante toggle
  emoji/tastiera (`Icons.emoji_emotions_outlined`/`Icons.keyboard_outlined`), `_insertEmoji` e la
  classe `_EmojiPicker` da `chat_home_screen.dart`. L'utente resta libero di scrivere emoji dalla
  tastiera del sistema; l'assistente continua comunque a usarle nelle risposte
  (`ASSISTANT_PERSONA`), quella parte non è cambiata.
- **"Ricerca" tolta dalla barra di navigazione, sostituita da "Appuntamenti"** (richiesta esplicita
  dell'utente) — la quarta voce della barra ora apre una nuova `AppointmentsOverviewScreen`
  (`/appuntamenti`), che aggrega i promemoria di **tutti** i Workspace dell'utente in un unico
  calendario, stesso principio già usato da `BalanceOverviewScreen` per il Bilancio globale:
  `CalendarEventRepository.watchEvents` guadagna un `workspaceId` nullable (`null` = tutti i
  Workspace, stessa forma già usata da `TransactionRepository.watchTransactions`). Il calendario "a
  quadratini" (`_MonthCalendarGrid`/`_DayCell`) è stato estratto da `reminder_list_screen.dart` in
  un nuovo widget condiviso pubblico `shared/widgets/month_calendar_grid.dart`
  (`MonthCalendarGrid`), riusato da entrambe le schermate. Nessun FAB nella vista globale: un
  promemoria appartiene sempre a un Workspace preciso, la creazione resta lì o via Chat — toccare
  una riga apre `/workspace/:id/reminders` per modificarla/eliminarla. La Ricerca Universale
  **non è stata rimossa** (resta uno dei pilastri di prodotto): la schermata `SearchScreen` è
  invariata, solo spostata fuori dallo `StatefulShellRoute` (una route di primo livello come
  login/onboarding, non più una delle 5 destinazioni principali) e raggiungibile da una nuova
  icona nell'intestazione della Chat Home.
- **Ricerca nelle Transazioni confermate, dentro il Bilancio** (richiesta esplicita dell'utente:
  "la ricerca potrei comunque inserirla nel bilancio per ricercare le spese") — nuovo campo di
  testo in `BalanceOverviewScreen`, sopra l'elenco "Transazioni confermate": filtra per descrizione
  o tag (case-insensitive), solo quell'elenco — saldo/grafico/budget restano invariati, stesso
  principio già usato dalla tendina del mese per la sola sezione "In attesa di conferma". **Nota
  tecnica sui test**: un `TextField` porta con sé un secondo `Scrollable` interno (l'`EditableText`
  lo usa per scrollare il cursore in vista) — ogni `scrollUntilVisible` in
  `balance_overview_screen_test.dart` ha dovuto essere ristretto esplicitamente con `scrollable:
  find.byType(Scrollable).first` (altrimenti `find.byType(Scrollable)` diventa ambiguo), e il test
  del dialog "Imposta un budget" ha dovuto restringere `find.byType(TextField)` con
  `find.descendant(of: find.byType(AlertDialog), ...)` per non confondersi con il nuovo campo di
  ricerca sotto.
- **Identità PWA personalizzata** (richiesta esplicita dell'utente, migliorie grafiche) —
  `manifest.json`/`index.html` aggiornati con nome/descrizione/colore tema del brand ("PIP —
  Personal Intelligence Platform", `#2563EB`, la stessa tinta di `AppColors.heroGradient`); icone
  (`icons/Icon-192.png`, `icons/Icon-512.png`, `icons/Icon-maskable-192.png`,
  `icons/Icon-maskable-512.png`, `favicon.png`) rigenerate con un gradiente blu→viola e una bolla
  di chat stilizzata, coerenti con l'identità visiva già usata in Chat/Bilancio, al posto delle
  icone segnaposto di Flutter.
- **Micro-animazioni di conferma** (richiesta esplicita dell'utente) — nuovo widget condiviso
  `shared/widgets/success_pulse.dart` (`SuccessPulse`): un "pop" (scala 1.0 → 1.35 → 1.0 su
  380ms) che si attiva solo sul fronte di salita `play` falso→vero, non ad ogni rebuild. Usato dal
  Checkbox di un'Attività completata (`task_list_screen.dart`) e dal pulsante "Conferma" di una
  Transazione pending in Chat (`chat_home_screen.dart`, con stato locale `_justConfirmed` per un
  feedback immediato indipendente dal tempismo del realtime).
- **Heatmap delle spese nel Bilancio** (richiesta esplicita dell'utente) — nuova funzione pura
  `dailyExpenseTotals` (`transaction_controller.dart`): uscite confermate per giorno del mese
  selezionato. Nuovo widget `_ExpenseHeatmap` in `balance_overview_screen.dart`, un calendario a
  quadratini colorati con intensità proporzionale alla spesa del giorno (stesso linguaggio visivo
  di `MonthCalendarGrid`, `Color.alphaBlend` su `AppColors.error`), tra "Andamento ultimi 6 mesi" e
  i Budget per categoria. Puramente visiva, nessun tocco/interazione: il dettaglio giorno per
  giorno resta nell'elenco delle Transazioni confermate già presente sotto.

- **ai-chat: `query_balance_summary` ora risponde anche senza un periodo specifico** (bug segnalato
  dall'utente: "perché l'assistente non ha visibilità diretta sul totale ufficiale delle spese
  confermate? Dovrebbe averne... vorrei che non dicesse di controllare la sezione bilancio ma che
  mi desse tutte le informazioni in chat") — prima `period_start`/`period_end` erano entrambi
  obbligatori nello schema dello strumento: una domanda senza un periodo esplicito (es. "quanto ho
  speso in totale", "il totale ufficiale delle spese confermate") non aveva un modo pulito di
  essere risolta in date concrete, e il modello finiva per rimandare l'utente alla sezione
  Bilancio invece di rispondere. Ora entrambi i campi sono opzionali: omessi, `queryBalanceSummary`
  (Edge Function `ai-chat`) non applica alcun limite di data e restituisce il totale su tutte le
  transazioni confermate registrate da sempre — stesso identico filtro `status = confirmed` /
  esclusione dei Bilanci condivisi già usato per un periodo delimitato, nessuna approssimazione.
  `QUERY_TOOL_INSTRUCTIONS` istruisce ora esplicitamente il modello a non rimandare mai l'utente
  alla sezione Bilancio per un dato che può ottenere da solo con questo strumento. Verificato solo
  con `deno check`/`lint`/`fmt` (nessuna chiamata reale ad Anthropic disponibile in questa
  sandbox, stesso limite già accettato per il resto di questo file).

- **Grafico a torta del Bilancio: più profondità 3D, stessa palette** (richiesta esplicita
  dell'utente: "deve essere più bello esteticamente... profondità dettata non solo da ombre...
  senza stravolgere il colore") — `_BalancePieChart` in `balance_overview_screen.dart`: il
  gradiente di ogni fetta passa da lineare a due tonalità a **radiale a tre tonalità**
  (`RadialGradient` con fuoco in alto a sinistra: schiarito verso il centro luce, tinta piena,
  leggermente scurito verso il bordo esterno) — simula una superficie sferica illuminata invece di
  un colore piatto con un solo passaggio, restando dentro la stessa famiglia `AppColors.heroGradient`
  (nessun colore nuovo). Aggiunto anche un sottile arco "riflesso vetro" (un unico settore bianco
  semi-trasparente, sfumato ai due estremi, centrato in cima all'anello tramite `startDegreeOffset`)
  sopra l'anello colorato, in un layer `IgnorePointer` separato per non intercettare i tocchi
  destinati al grafico interattivo sottostante — stesso `centerSpaceRadius`/`radius` del grafico
  reale, quindi sempre allineato senza calcoli manuali di geometria (stesso `Stack` centrato già
  usato per la copia-ombra esistente). Verificato visivamente catturando uno screenshot del widget
  renderizzato offscreen (`matchesGoldenFile` in un test temporaneo, poi rimosso) — nessun browser
  reale necessario per questo controllo.

- **Pass di rifinitura estetica** (richiesta esplicita dell'utente: "abbellimenti stilistici",
  non layout/architettura) — tre migliorie indipendenti, tutte presentazione pura:
  - **Coerenza delle intestazioni**: le 4 schermate rimaste con un `AppBar`/`SliverAppBar` piatto
    ora usano lo stesso gradiente "premium" già in Chat/Bilancio — `MemoryListScreen`,
    `WorkspaceMemoryListScreen`, `ProfileScreen` (passati a `GradientAppBar`, lo stesso widget
    condiviso) e `WorkspaceDetailScreen` (`SliverAppBar` con `flexibleSpace` dello stesso
    gradiente, non `GradientAppBar` direttamente: è dentro un `CustomScrollView` per il
    comportamento `floating`, non un `Scaffold.appBar` semplice).
  - **Shimmer sullo skeleton loading**: `shared/widgets/skeleton_list.dart` — sostituita la
    dissolvenza di opacità uniforme con un vero effetto "shimmer" (`ShaderMask` con
    `BlendMode.srcATop`, una banda di luce che attraversa ogni riga in un giro continuo), stesso
    principio del pacchetto `shimmer` più diffuso senza aggiungere una dipendenza. Si propaga
    automaticamente a ogni schermata che usa `SkeletonList` (un solo widget condiviso).
  - **Effetto "vetro" esteso**: lo stesso gradiente radiale con fuoco di luce in alto a sinistra
    già usato per le fette del grafico a torta è ora applicato anche all'avatar del Profilo
    (tonalità bianche, sopra il gradiente colorato dell'hero) e al disco centrale del donut nel
    Bilancio (un accenno molto tenue, per non intaccare la leggibilità del testo sopra).
  Verificato visivamente con screenshot offscreen (`matchesGoldenFile` in test temporanei, poi
  rimossi), stesso metodo già usato per il grafico a torta.

- **Splash coerente all'avvio** (richiesta esplicita dell'utente, migliorie miste
  estetiche/funzionali) — `web/index.html`: un overlay a schermo intero con lo stesso gradiente
  `AppColors.heroGradient` e l'icona dell'app pulsante, al posto del lampo bianco prima che Flutter
  finisca di caricarsi. Rimosso in JavaScript puro all'evento standard `flutter-first-frame`
  (emesso dal motore Flutter Web una volta dipinto il primo fotogramma reale), mai lasciato a
  copertura permanente. Anche lo sfondo di `html`/`body` è impostato sullo stesso gradiente, come
  rete di sicurezza se lo splash sparisse prima che Flutter sia pronto su una rete lenta.
- **Lightbox sulle foto allegate** (integrazione richiesta esplicitamente) — `DocumentThumbnail`
  (widget condiviso, usato sia in Chat sia nella lista Documenti): un tocco sull'immagine già
  caricata apre un visualizzatore a schermo intero (`InteractiveViewer`, pan/zoom fino a 4×) invece
  di restare piccola. Solo sul caso "immagine caricata con successo" — un tocco su un
  caricamento/errore non apre nulla. Verificato con `tester.takeException()` per consumare
  l'inevitabile `NetworkImageLoadException` di `Image.network` in `flutter test` (nessuna vera
  rete nel test binding, nessun `mockNetworkImagesFor` in questo progetto).
- **"Annulla" su eliminazioni** (integrazione richiesta esplicitamente) — nuova utility condivisa
  `shared/utils/undoable_delete.dart` (`scheduleUndoableDelete`): mostra uno SnackBar con l'azione
  "Annulla" e posticipa di 4 secondi la cancellazione reale, invece di eseguirla subito. Applicata
  a tutte e quattro le liste con swipe-to-delete (Attività, Note, Promemoria, Documenti), ciascuna
  con il proprio insieme locale di id "scartati" per nascondere l'elemento durante l'attesa e farlo
  ricomparire se l'utente annulla — `TaskListScreen` è passata da `ConsumerWidget` a
  `ConsumerStatefulWidget` per poter tenere quello stato, le altre tre schermate erano già
  Stateful. **Eccezione voluta**: l'eliminazione dell'intera serie di un promemoria ricorrente
  resta immediata, senza "Annulla" — quella scelta (singola occorrenza o serie intera) è già una
  conferma esplicita a sé, per non riscrivere quel flusso già testato. Nei test, `pumpAndSettle()`
  da solo non basta ad aspettare il timer di 4 secondi (una `Timer` pura non "schedula un
  fotogramma" come farebbe un'animazione, quindi `pumpAndSettle()` la considera già assestata):
  serve un `tester.pump(Duration(seconds: 5))` esplicito dopo la conferma.
- **Filtro per categoria nel Bilancio** (richiesta esplicita dell'utente) — sopra l'elenco delle
  transazioni confermate, una striscia orizzontale di `FilterChip` (una per categoria presente nel
  mese selezionato, ordinate per etichetta) affianca la ricerca testuale già esistente: toccare una
  categoria la seleziona/deseleziona, e i due filtri (testo + categoria) si combinano. La striscia
  resta nascosta quando c'è al più una categoria (non avrebbe nulla da filtrare).
- **Animazione d'ingresso sui grafici** (richiesta esplicita dell'utente) — `_TrendChart` e
  `_CategoryTrendChart` (entrambi basati su `BarChart` di `fl_chart`, che estende già
  `ImplicitlyAnimatedWidget`) partono con tutte le barre a altezza zero e, dopo il primo
  fotogramma (`addPostFrameCallback`), passano al valore reale — l'animazione di interpolazione
  (`swapAnimationDuration: 600ms`, `swapAnimationCurve: Curves.easeOutCubic`) è già incorporata nel
  widget, nessun `AnimationController` scritto a mano. L'heatmap delle spese (`_ExpenseHeatmap`,
  senza stato proprio) usa invece un `TweenAnimationBuilder` per un semplice dissolvenza in
  ingresso (`Opacity` da 0 a 1 in 500ms). Verificato visivamente con uno screenshot offscreen a
  metà animazione (poi rimosso, stesso metodo già usato per le altre migliorie grafiche) — nei
  test automatici serve un `pump()` in più rispetto al solito prima di far avanzare l'orologio: il
  primo `pump()` risolve i provider, il secondo fa scattare il rebuild innescato da
  `addPostFrameCallback` (che avvia l'animazione con `elapsed=0`), solo allora un terzo `pump`
  con una durata avanza l'animazione già partita.
- **Coach mark leggero sulle funzioni nuove** (richiesta esplicita dell'utente) — nuovo widget
  condiviso `shared/widgets/coach_mark.dart` (`CoachMark`): un piccolo banner non invasivo (stesso
  gradiente `AppColors.heroGradient` dell'header), mostrato sopra un widget la prima volta che
  compare, con un pulsante di chiusura esplicito. Applicato a due punti già esistenti ma poco
  scoperti: il calendario mensile in Appuntamenti ("tocca un giorno per filtrare") e la heatmap
  delle spese nel Bilancio ("più intenso il colore, più hai speso"). Lo stato "già visto" è
  puramente locale al dispositivo (nessun dato di dominio, nessuna sincronizzazione tra dispositivi
  necessaria per un suggerimento grafico): persistito con `shared_preferences`, prima dipendenza di
  storage locale in questo progetto — ogni altro stato "già visto" (es. onboarding) vive lato
  Supabase perché deve restare coerente tra i dispositivi dello stesso utente, cosa non
  necessaria qui. Nei test, `SharedPreferences.setMockInitialValues(...)` (hook ufficiale del
  package) sostituisce l'istanza reale, senza bisogno di un repository fittizio dedicato.

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
