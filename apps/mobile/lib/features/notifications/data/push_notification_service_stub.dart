import 'push_notification_service.dart';

/// Implementazione no-op per piattaforme non web (import condizionale, vedi
/// `push_notification_service_provider.dart`): l'app resta compilabile e
/// utilizzabile anche se un giorno girasse fuori dal browser, semplicemente
/// senza il pulsante "Attiva notifiche" in Profilo.
PushNotificationService createPushNotificationService() =>
    _StubPushNotificationService();

class _StubPushNotificationService implements PushNotificationService {
  @override
  Future<PushSupportStatus> checkStatus() async =>
      PushSupportStatus.unsupported;

  @override
  Future<PushSubscriptionKeys?> subscribe(String vapidPublicKey) async =>
      null;
}
