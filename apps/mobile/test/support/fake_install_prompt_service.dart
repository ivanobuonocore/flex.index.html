import 'dart:async';

import 'package:pip_mobile/features/pwa_install/data/install_prompt_service.dart';

class FakeInstallPromptService implements InstallPromptService {
  final _controller = StreamController<bool>.broadcast();
  int promptCallCount = 0;

  void emit(bool available) => _controller.add(available);

  @override
  Stream<bool> watchAvailability() => _controller.stream;

  @override
  Future<void> promptInstall() async {
    promptCallCount++;
  }

  void dispose() => _controller.close();
}
