import 'package:flutter/widgets.dart';

/// Raggi degli angoli (docs/product/05-design-system.md, "Bordi").
abstract final class AppRadii {
  static const double standard = 16;
  static const double cardPremium = 24;
  static const double button = 14;
  static const double input = 16;

  /// Arrotondamento "a pillola" per chip/badge — sempre completamente
  /// arrotondato indipendentemente dall'altezza del contenitore (redesign
  /// estetico), invece del valore fisso di [standard].
  static const double pill = 999;

  static BorderRadius get standardRadius => BorderRadius.circular(standard);
  static BorderRadius get cardPremiumRadius =>
      BorderRadius.circular(cardPremium);
  static BorderRadius get buttonRadius => BorderRadius.circular(button);
  static BorderRadius get inputRadius => BorderRadius.circular(input);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
}
