import 'package:pip_shared/pip_shared.dart';

/// Confine verso la persistenza delle iscrizioni Web Push, implementato nel
/// layer `data` di ogni app (Dependency Inversion — Engineering Constitution,
/// Articolo 4). Nessuna entità ricca: un'iscrizione non ha uno stato da
/// mostrare in UI, solo da salvare e da usare lato server per l'invio.
abstract interface class PushSubscriptionRepository {
  /// Salva (o aggiorna, se [endpoint] esiste già) l'iscrizione Web Push
  /// dell'utente autenticato — livello account, non Workspace (le notifiche
  /// non appartengono a un singolo Workspace).
  Future<Result<Unit>> saveSubscription({
    required String endpoint,
    required String p256dh,
    required String authKey,
  });

  /// Invia una notifica di prova a tutte le iscrizioni dell'utente
  /// autenticato, tramite l'Edge Function `send-test-push`.
  Future<Result<Unit>> sendTestNotification();
}
