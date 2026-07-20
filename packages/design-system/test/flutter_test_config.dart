import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// `AppTypography` evita `GoogleFonts.manrope()` sotto `flutter test`
/// (`isRunningInFlutterTest`, in `lib/src/testing/`), quindi non serve altro
/// qui oltre a inizializzare il binding per i test non-widget come
/// `theme_test.dart`. Riconosciuto automaticamente da `flutter test`/`dart
/// test` per tutti i test in questa cartella.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await testMain();
}
