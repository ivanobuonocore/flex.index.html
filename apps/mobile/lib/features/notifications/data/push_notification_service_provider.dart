import 'push_notification_service.dart';
import 'push_notification_service_stub.dart'
    if (dart.library.js_interop) 'push_notification_service_web.dart'
    as impl;

/// Sceglie l'implementazione a compile time in base alla piattaforma
/// (`dart.library.js_interop` esiste solo quando si compila per il web) —
/// pattern standard Flutter per codice platform-specific, coerente con
/// l'astrazione `PushNotificationService` che il resto dell'app usa.
PushNotificationService createPushNotificationService() =>
    impl.createPushNotificationService();
