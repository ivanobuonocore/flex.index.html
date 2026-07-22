import 'package:pip_shared/pip_shared.dart';

import '../entities/calendar_connection.dart';

/// Confine verso il collegamento a Google Calendar (Fase 3, "Sync con Google
/// Calendar" — integrazione richiesta esplicitamente), implementato nel
/// layer `data` di ogni app (Dependency Inversion — Engineering
/// Constitution, Articolo 4). Non collega mai il frontend direttamente a
/// Google: ogni chiamata passa da una Edge Function (CLAUDE.md, "mai
/// collegare il frontend direttamente a un provider", qui esteso per
/// analogia a qualsiasi provider terzo, non solo un LLM).
abstract interface class CalendarSyncRepository {
  /// Stato del collegamento dell'utente corrente (`null` = non collegato).
  /// Non è uno stream realtime come le altre entità dell'app: il refresh
  /// token OAuth non deve mai transitare nel canale realtime di Supabase
  /// (che invierebbe l'intera riga, token incluso, ad ogni update) — letto
  /// invece con una singola chiamata a una funzione Postgres `security
  /// definer` che restituisce solo i campi non sensibili.
  Future<Result<CalendarConnection?>> fetchConnectionStatus();

  /// Avvia il collegamento (redirect OAuth verso Google tramite Supabase
  /// Auth, `linkIdentity`) — richiede che il provider Google sia abilitato
  /// nel dashboard Supabase con lo scope Calendar (passo manuale, vedi
  /// `infrastructure/supabase/README.md`). Ritorna un errore solo se il
  /// redirect stesso non può partire (es. provider non configurato); il
  /// salvataggio effettivo avviene altrove — l'implementazione ascolta da
  /// sé i cambi di sessione e invia il refresh token alla Edge Function
  /// `save-calendar-connection` non appena Supabase lo espone, perché il
  /// completamento arriva in modo asincrono al ritorno dell'utente
  /// nell'app, non nella stessa chiamata.
  Future<Result<Unit>> beginConnect();

  Future<Result<Unit>> disconnect();
}
