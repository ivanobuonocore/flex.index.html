import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'base64_url_codec.dart';
import 'push_notification_service.dart';

/// URL relativo del service worker dedicato alle notifiche (distinto da
/// `flutter_service_worker.js`, gestito da Flutter) — vedi
/// `apps/mobile/web/push-worker.js`.
const _pushWorkerUrl = 'push-worker.js';

/// Implementazione reale via Web Push (RFC 8291), scelta a compile time per
/// il target web (vedi `push_notification_service_provider.dart`). Non
/// verificabile con `flutter test` (nessun browser nel test runner): la
/// correttezza della forma dell'interop è verificata da `flutter analyze`
/// contro le API reali di `package:web`; il comportamento a runtime (permesso
/// concesso, notifica effettivamente recapitata) va verificato manualmente
/// nel browser (apps/mobile/README.md, "Limiti noti").
PushNotificationService createPushNotificationService() =>
    _WebPushNotificationService();

class _WebPushNotificationService implements PushNotificationService {
  @override
  Future<PushSupportStatus> checkStatus() async {
    try {
      final registration = await _registerServiceWorker();
      final subscription =
          await registration.pushManager.getSubscription().toDart;
      return subscription == null
          ? PushSupportStatus.notSubscribed
          : PushSupportStatus.subscribed;
    } catch (_) {
      // Qualunque eccezione qui (API assente, permesso negato dal sistema,
      // contesto non sicuro) significa "non supportato" per l'utente: non è
      // un errore da mostrare, solo un pulsante da tenere disattivato.
      return PushSupportStatus.unsupported;
    }
  }

  @override
  Future<PushSubscriptionKeys?> subscribe(String vapidPublicKey) async {
    try {
      final permission = await web.Notification.requestPermission().toDart;
      if (permission.toDart != 'granted') return null;

      final registration = await _registerServiceWorker();
      final applicationServerKey = decodeBase64Url(vapidPublicKey);
      final subscription = await registration.pushManager
          .subscribe(
            web.PushSubscriptionOptionsInit(
              userVisibleOnly: true,
              applicationServerKey: applicationServerKey.toJS,
            ),
          )
          .toDart;

      final p256dhBuffer = subscription.getKey('p256dh');
      final authBuffer = subscription.getKey('auth');
      if (p256dhBuffer == null || authBuffer == null) return null;

      return PushSubscriptionKeys(
        endpoint: subscription.endpoint,
        p256dh: encodeBase64Url(p256dhBuffer.toDart.asUint8List()),
        authKey: encodeBase64Url(authBuffer.toDart.asUint8List()),
      );
    } catch (_) {
      return null;
    }
  }

  /// `register()` è idempotente (stesso script+scope ritorna la registrazione
  /// esistente): usarlo anche solo per leggere lo stato evita di duplicare la
  /// logica di ricerca di una registrazione già attiva.
  Future<web.ServiceWorkerRegistration> _registerServiceWorker() =>
      web.window.navigator.serviceWorker.register(_pushWorkerUrl.toJS).toDart;
}
