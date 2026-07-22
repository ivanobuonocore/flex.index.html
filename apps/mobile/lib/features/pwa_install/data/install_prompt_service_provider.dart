import 'install_prompt_service.dart';
import 'install_prompt_service_stub.dart'
    if (dart.library.js_interop) 'install_prompt_service_web.dart' as impl;

/// Sceglie l'implementazione a compile time in base alla piattaforma —
/// stesso pattern già usato da
/// `notifications/data/push_notification_service_provider.dart`.
InstallPromptService createInstallPromptService() =>
    impl.createInstallPromptService();
