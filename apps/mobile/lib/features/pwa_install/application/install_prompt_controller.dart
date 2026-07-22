import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/install_prompt_service.dart';
import '../data/install_prompt_service_provider.dart';

/// Interop col browser (evento `beforeinstallprompt`) — mai chiamato
/// direttamente dalla UI, sempre tramite [installAvailableProvider]/
/// [promptInstallControllerProvider] (Dependency Inversion, stesso principio
/// dei repository di dominio).
final installPromptServiceProvider = Provider<InstallPromptService>((ref) {
  return createInstallPromptService();
});

/// `true` quando il browser ha reso disponibile il prompt di installazione,
/// `false` (mai `null`) prima che arrivi un evento o dopo un'installazione —
/// usato dalla card "Installa l'app" in Profilo per decidere se mostrarsi.
/// Uno `StreamProvider` (non un `Future`) perché l'evento può arrivare in
/// qualunque momento dopo l'avvio, non una tantum al primo `watch`.
final installAvailableProvider = StreamProvider.autoDispose<bool>((ref) {
  return ref.watch(installPromptServiceProvider).watchAvailability();
});

final promptInstallControllerProvider =
    AsyncNotifierProvider.autoDispose<PromptInstallController, void>(
  PromptInstallController.new,
);

class PromptInstallController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> promptInstall() async {
    state = const AsyncLoading();
    await ref.read(installPromptServiceProvider).promptInstall();
    state = const AsyncData(null);
  }
}
