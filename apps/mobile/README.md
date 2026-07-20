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

Strutturate e navigabili, in attesa delle rispettive fasi della roadmap
(`docs/product/26-execution-blueprint.md`):

- **profile** — identità account e logout ora; abbonamento, tema, memoria, privacy nelle fasi
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
