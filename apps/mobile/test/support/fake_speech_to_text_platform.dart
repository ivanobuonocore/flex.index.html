import 'dart:convert';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

/// Sostituisce [SpeechToTextPlatform.instance] (il seam di test ufficiale del
/// plugin federato, lo stesso usato dalla sua implementazione web reale) per
/// verificare la dettatura vocale in Chat (integrazione richiesta
/// esplicitamente) senza un vero canale nativo/browser. `flutter test` gira
/// sulla Dart VM: senza questo fake, `SpeechToText.initialize()` userebbe il
/// vero `MethodChannelSpeechToText`, che senza un plugin registrato solleva
/// una `MissingPluginException` — trattata da `chat_home_screen.dart` come
/// "dettatura non disponibile", non un crash (stesso comportamento di un
/// browser senza Web Speech API).
class FakeSpeechToTextPlatform extends SpeechToTextPlatform {
  bool initializeResult = true;
  bool listenResult = true;
  int stopCallCount = 0;
  int listenCallCount = 0;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> initialize({
    debugLogging = false,
    List<SpeechConfigOption>? options,
  }) async {
    return initializeResult;
  }

  @override
  Future<bool> listen({
    String? localeId,
    partialResults = true,
    onDevice = false,
    int listenMode = 0,
    sampleRate = 0,
    SpeechListenOptions? options,
  }) async {
    listenCallCount += 1;
    return listenResult;
  }

  @override
  Future<void> stop() async {
    stopCallCount += 1;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<List<dynamic>> locales() async => const [];

  /// Simula una trascrizione riconosciuta, richiamando lo stesso callback
  /// (`onTextRecognition`) che l'implementazione nativa/web reale invoca —
  /// [SpeechToText] lo registra durante `initialize()`.
  void emitResult(String recognizedWords, {bool isFinal = true}) {
    final json = jsonEncode({
      'alternates': [
        {
          'recognizedWords': recognizedWords,
          'recognizedPhrases': null,
          'confidence': 1.0,
        },
      ],
      'resultType':
          (isFinal ? ResultType.finalResult : ResultType.partial).value,
    });
    onTextRecognition?.call(json);
  }
}
