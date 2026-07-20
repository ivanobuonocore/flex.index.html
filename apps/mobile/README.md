# apps/mobile

App Flutter principale (MVP). Architettura Feature First: ogni feature sotto
`lib/features/<nome>/` con sottocartelle `presentation/ application/ domain/ data/`
(solo quelle necessarie — vedi AI Engineering Playbook).

State management: Riverpod. Routing: GoRouter (`StatefulShellRoute.indexedStack` per la
Bottom Navigation a 5 sezioni).

## Stato

Implementate, con dati reali via Supabase:

- **auth** (Fase 1) — login, registrazione, sessione, logout.
- **workspace** (Fase 1 + Fase 2 slice 1/2) — lista, creazione, Home del Workspace
  (`/workspace/:id`) con anteprima Note/Task/Documenti e menu verso le sezioni non ancora
  implementate.
- **note** (Fase 2 slice 1) — CRUD completo per Workspace (`/workspace/:id/notes`), realtime.
- **task** (Fase 2 slice 1) — CRUD completo per Workspace (`/workspace/:id/tasks`), realtime,
  toggle rapido todo↔done.
- **document** (Fase 2 slice 2) — upload/apertura/eliminazione per Workspace
  (`/workspace/:id/documents`), Supabase Storage con signed URL, realtime.
- **search** (Fase 2 slice 3) — Ricerca Universale cross-tabella (Workspace/Note/Task/
  Documenti) via full-text search Postgres, debounce lato UI.
- **chat** (Fase 3 slice 1, foto in slice 3, **Home dell'app da slice 4** — richiesta esplicita
  dell'utente) — `/chat` è ora la prima schermata dopo il login: saluto, Workspace recenti, e
  tutte le Chat dell'utente (private o di un Workspace), con creazione diretta da qui (scelta del
  Workspace o chat privata). Da una Chat di Workspace, un pulsante "cartelle" nell'AppBar apre
  Note/Attività/Documenti/Bilancio di quel Workspace senza passare dalla tab Workspace. Resta
  anche l'accesso da dentro un Workspace (`/workspace/:id/chat`). Invio messaggio + risposta AI in
  tempo reale (realtime, non streaming token-by-token), indicatore "l'assistente sta scrivendo".
  Il frontend non chiama mai direttamente Anthropic: ogni messaggio passa dall'Edge Function
  `ai-chat` (`infrastructure/supabase/functions/ai-chat`), l'unico punto in cui l'app tocca un
  provider AI. Si può allegare una foto a un messaggio (solo dentro un Workspace, non in Chat
  private): la foto viene caricata come `Document` (stesso bucket/sezione di Documenti, riusati —
  nessuna nuova infrastruttura) e l'assistente la "vede" tramite il supporto immagini di Claude.
- **transaction** (Fase 3 slice 2, aggiunta oltre allo scaffold originale — richiesta reale
  dell'utente, ispirata all'app Planito) — Bilancio per Workspace (`/workspace/:id/transactions`):
  saldo del mese corrente (entrate meno uscite confermate) + lista con totali separati, aggiunta
  manuale (entrata o uscita), e una sezione "in attesa di conferma" per le transazioni che la
  Chat ha riconosciuto in un messaggio (es. "barbiere 23€, supermercato 35€" oppure "ho ricevuto
  lo stipendio di 1500€") ma che l'utente non ha ancora confermato — nessuna transazione
  suggerita dall'AI conta nel saldo finché non viene confermata esplicitamente (AI Constitution,
  Principio 1).
- **notifications** (Fase 3 slice 4, aggiunta oltre allo scaffold originale — richiesta reale
  dell'utente, che ha esplicitamente rifiutato l'alternativa "elenco promemoria solo in app" per
  volere notifiche di sistema vere) — prima slice: attivazione (permesso + iscrizione Web Push) e
  un pulsante "Invia una notifica di prova" nella card "Notifiche" del Profilo. Visibile solo se
  l'app è stata compilata con `VAPID_PUBLIC_KEY` (facoltativa: l'app resta utilizzabile anche
  senza). Non ancora i Promemoria veri (`CalendarEvent`, già modellato in `packages/domain` ma non
  implementato) — questa slice prova solo che la catena di consegna funziona.

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
