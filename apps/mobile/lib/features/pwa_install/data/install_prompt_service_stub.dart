import 'dart:async';

import 'install_prompt_service.dart';

/// Implementazione no-op per piattaforme non web (import condizionale, vedi
/// `install_prompt_service_provider.dart`): l'evento `beforeinstallprompt`
/// esiste solo nel browser, quindi qui non arriva mai nulla e la card
/// "Installa l'app" resta sempre nascosta.
InstallPromptService createInstallPromptService() =>
    _StubInstallPromptService();

class _StubInstallPromptService implements InstallPromptService {
  @override
  Stream<bool> watchAvailability() => const Stream.empty();

  @override
  Future<void> promptInstall() async {}
}
