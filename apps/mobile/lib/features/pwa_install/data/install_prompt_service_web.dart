import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'install_prompt_service.dart';

/// `beforeinstallprompt` è un evento proprietario di Chromium/Edge, non
/// nello standard W3C: non è nei binding generati di `package:web`, da cui
/// questo extension type minimo con solo il membro che serve qui
/// (`userChoice` non serve: dopo il prompt basta ascoltare `appinstalled`,
/// già standard, per sapere se l'utente ha accettato).
extension type _BeforeInstallPromptEvent(JSObject _) implements web.Event {
  external JSPromise<JSAny?> prompt();
}

/// Implementazione reale, scelta a compile time per il target web (vedi
/// `install_prompt_service_provider.dart`). Non verificabile con
/// `flutter test` (nessun browser nel test runner, e l'evento
/// `beforeinstallprompt` non è simulabile): la correttezza della forma
/// dell'interop è verificata da `flutter analyze` contro i tipi di
/// `package:web`; il comportamento a runtime va verificato manualmente in
/// Chrome/Edge (apps/mobile/README.md, "Limiti noti") — stesso trattamento
/// già riservato alle notifiche push.
InstallPromptService createInstallPromptService() => _WebInstallPromptService();

class _WebInstallPromptService implements InstallPromptService {
  _WebInstallPromptService() {
    web.window.addEventListener(
      'beforeinstallprompt',
      (_BeforeInstallPromptEvent event) {
        event.preventDefault();
        _deferredEvent = event;
        _availabilityController.add(true);
      }.toJS,
    );
    web.window.addEventListener(
      'appinstalled',
      (web.Event _) {
        _deferredEvent = null;
        _availabilityController.add(false);
      }.toJS,
    );
  }

  final _availabilityController = StreamController<bool>.broadcast();
  _BeforeInstallPromptEvent? _deferredEvent;

  @override
  Stream<bool> watchAvailability() => _availabilityController.stream;

  @override
  Future<void> promptInstall() async {
    final event = _deferredEvent;
    if (event == null) return;
    await event.prompt().toDart;
    _deferredEvent = null;
    _availabilityController.add(false);
  }
}
