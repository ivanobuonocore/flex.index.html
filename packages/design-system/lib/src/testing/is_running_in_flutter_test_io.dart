import 'dart:io';

/// `flutter test` imposta questa variabile d'ambiente sul processo VM che
/// esegue i test — non è documentata come API pubblica, ma è un comportamento
/// stabile della toolchain, già usato da altri package (es. `path_provider`)
/// per lo stesso scopo: distinguere l'esecuzione sotto test da quella reale.
bool get isRunningInFlutterTest =>
    Platform.environment['FLUTTER_TEST'] == 'true';
