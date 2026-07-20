/// Stato del supporto/iscrizione alle notifiche push sul dispositivo corrente.
enum PushSupportStatus {
  /// Il browser/piattaforma non supporta le notifiche push (es. Safari su
  /// iPhone quando il sito non è stato "Aggiunto alla schermata Home", oppure
  /// una piattaforma non web).
  unsupported,

  /// Supportate ma non ancora attivate dall'utente.
  notSubscribed,

  /// Già attive su questo dispositivo.
  subscribed,
}

/// Le tre credenziali Web Push (RFC 8291) restituite da una `PushSubscription`
/// del browser, da salvare lato server per l'invio.
class PushSubscriptionKeys {
  const PushSubscriptionKeys({
    required this.endpoint,
    required this.p256dh,
    required this.authKey,
  });

  final String endpoint;
  final String p256dh;
  final String authKey;
}

/// Confine verso l'interop col browser (Web Push, Service Worker, permessi di
/// notifica) — implementazione scelta a compile time in base alla piattaforma
/// (vedi `push_notification_service_provider.dart`, import condizionale su
/// `dart.library.js_interop`). Nessun metodo di questa interfaccia importa
/// `dart:js_interop` o `package:web`: solo le implementazioni concrete lo
/// fanno, così il resto dell'app non dipende da API che non esistono fuori
/// dal browser.
abstract interface class PushNotificationService {
  /// Stato attuale, senza chiedere permessi né effetti collaterali.
  Future<PushSupportStatus> checkStatus();

  /// Chiede il permesso di notifica, registra il service worker
  /// (`push-worker.js`) e si iscrive al push service del browser. Ritorna
  /// `null` se il permesso viene negato o la piattaforma non è supportata —
  /// mai un errore bloccante (Software Architecture, "Notifiche" — un
  /// dispositivo senza supporto non deve impedire l'uso dell'app).
  Future<PushSubscriptionKeys?> subscribe(String vapidPublicKey);
}
