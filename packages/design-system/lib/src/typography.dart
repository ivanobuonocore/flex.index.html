import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'testing/is_running_in_flutter_test.dart';

/// Font principale: Manrope (redesign estetico — richiesta esplicita
/// dell'utente: "rendi più estetica l'interfaccia... utilizzando un font
/// dedicato"). Caricato via `google_fonts`: nessun asset da bundlare nel
/// repo, cache e fallback di sistema (se offline) gestiti dal package.
///
/// Gerarchia tipografica (docs/product/05-design-system.md, "Tipografia").
abstract final class AppTypography {
  static final TextStyle display =
      _manrope(fontSize: 34, fontWeight: FontWeight.w700, height: 1.15);

  static final TextStyle heading1 =
      _manrope(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2);

  static final TextStyle heading2 =
      _manrope(fontSize: 22, fontWeight: FontWeight.w600, height: 1.25);

  static final TextStyle heading3 =
      _manrope(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3);

  static final TextStyle body =
      _manrope(fontSize: 16, fontWeight: FontWeight.w400, height: 1.4);

  static final TextStyle caption =
      _manrope(fontSize: 13, fontWeight: FontWeight.w400, height: 1.3);

  /// Sotto `flutter test` (VM, non browser) evita `GoogleFonts.manrope()`:
  /// scatenerebbe un fetch di rete verso fonts.gstatic.com fuori dal
  /// controllo del test, che in ambienti senza quell'accesso (non il caso
  /// della CI reale) fa fallire i test in modo non deterministico pur non
  /// avendo nulla a che fare con ciò che i test verificano davvero (colori,
  /// struttura del tema — mai il font effettivamente caricato).
  static TextStyle _manrope({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
  }) {
    if (isRunningInFlutterTest) {
      return TextStyle(
          fontSize: fontSize, fontWeight: fontWeight, height: height);
    }
    return GoogleFonts.manrope(
        fontSize: fontSize, fontWeight: fontWeight, height: height);
  }
}
