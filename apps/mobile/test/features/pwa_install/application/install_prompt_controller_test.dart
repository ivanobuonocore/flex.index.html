import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_mobile/features/pwa_install/application/install_prompt_controller.dart';

import '../../../support/fake_install_prompt_service.dart';

void main() {
  late FakeInstallPromptService fakeService;
  late ProviderContainer container;

  setUp(() {
    fakeService = FakeInstallPromptService();
    container = ProviderContainer(
      overrides: [
        installPromptServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fakeService.dispose);
  });

  test('installAvailableProvider riflette lo stream del service', () async {
    final sub = container.listen(installAvailableProvider, (_, __) {});
    addTearDown(sub.close);

    fakeService.emit(true);
    await Future<void>.delayed(Duration.zero);

    expect(sub.read().value, isTrue);

    fakeService.emit(false);
    await Future<void>.delayed(Duration.zero);

    expect(sub.read().value, isFalse);
  });

  test('promptInstall delega al service', () async {
    await container
        .read(promptInstallControllerProvider.notifier)
        .promptInstall();

    expect(fakeService.promptCallCount, 1);
  });
}
