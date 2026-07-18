import 'package:flutter/widgets.dart';

/// Font principale: Inter (docs/product/05-design-system.md, "Tipografia").
///
/// I file del font vanno aggiunti in `apps/mobile/assets/fonts/` e
/// dichiarati nel `pubspec.yaml` dell'app prima del rilascio; nel frattempo
/// il sistema operativo risolve `fontFamily` con il proprio fallback, senza
/// alcun impatto sulla struttura del Design System.
const String appFontFamily = 'Inter';

/// Gerarchia tipografica (docs/product/05-design-system.md, "Tipografia").
abstract final class AppTypography {
  static const TextStyle display = TextStyle(
    fontFamily: appFontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );

  static const TextStyle heading1 = TextStyle(
    fontFamily: appFontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: appFontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: appFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontFamily: appFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: appFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );
}
