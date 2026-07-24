import 'package:flutter/animation.dart';

/// Durate e curve delle animazioni (docs/product/05-design-system.md,
/// "Animazioni" — 180–250ms, curve morbide).
abstract final class AppMotion {
  /// Nessuna animazione: da usare quando l'utente preferisce movimenti
  /// ridotti. I widget applicativi leggono questa preferenza via
  /// [MediaQuery.disableAnimations].
  static const Duration instant = Duration.zero;

  /// Feedback immediato per pressione di pulsanti, icone e FAB.
  static const Duration press = Duration(milliseconds: 140);

  /// Hover e micro-feedback di superfici interattive.
  static const Duration fast = Duration(milliseconds: 200);

  /// Ingresso di card, menu e modali.
  static const Duration standard = Duration(milliseconds: 240);

  /// Transizioni tra schermate e cambi di tema.
  static const Duration slow = Duration(milliseconds: 280);

  /// Grafici e count-up: abbastanza visibili da comunicare il dato, mai
  /// abbastanza lunghi da rallentare la navigazione.
  static const Duration chart = Duration(milliseconds: 720);
  static const Duration countUp = Duration(milliseconds: 760);

  static const Curve curve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Curve enter = Curves.easeOutCubic;

  /// Curva "emphasized" (accelerazione dolce, decelerazione più marcata in
  /// coda — stile Apple/Material 3), in aggiunta a [curve]: per pressioni e
  /// transizioni di pagina del redesign estetico. Non sostituisce [curve],
  /// già usata da animazioni implicite esistenti e verificate visivamente.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  static const double pressedScale = 0.975;
  static const double hoverScale = 1.012;
  static const double cardHoverLift = -3;
}
