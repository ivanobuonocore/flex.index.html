import 'package:flutter/widgets.dart';

/// Palette (docs/product/05-design-system.md, versione "aggiornata rispetto
/// al Capitolo 3" — fonte di verità finché la nota di consolidamento nel
/// documento non viene risolta).
abstract final class AppColors {
  // Light mode
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color primaryLight = Color(0xFF2563EB);
  static const Color secondaryLight = Color(0xFF7C3AED);
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // Dark mode
  static const Color backgroundDark = Color(0xFF111827);
  static const Color cardDark = Color(0xFF1F2937);
  static const Color primaryDark = Color(0xFF60A5FA);
  static const Color secondaryDark = Color(0xFFA78BFA);
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  // Stati semantici, comuni a light e dark mode.
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Sezioni fisse (Fase 3, "Sezioni fisse" — un colore distintivo per
  // categoria, comune a light e dark mode, per riconoscerle a colpo
  // d'occhio nella striscia "Sezioni" e ovunque compaia una WorkspaceCard).
  static const Color categoryBilancio = Color(0xFF16A34A);
  static const Color categoryAppuntamenti = Color(0xFF2563EB);
  static const Color categoryAttivita = Color(0xFFF97316);
  static const Color categoryDocumenti = Color(0xFF0D9488);

  // Accenti per Note/Documenti nelle liste "semplici" (non sezioni fisse):
  // stesso principio di categoryAttivita/categoryDocumenti, comune a light e
  // dark mode (redesign estetico — richiesta esplicita dell'utente: "icone
  // colorate" in tutta l'interfaccia, non solo nelle sezioni fisse).
  static const Color accentNote = Color(0xFFCA8A04);

  // Gradiente ispirato al "glow" di Siri quando si attiva (redesign
  // estetico — richiesta esplicita dell'utente), usato per il pulsante Chat
  // al centro della barra di navigazione. Comune a light e dark mode: è
  // pensato per risaltare su entrambi gli sfondi, non per adattarsi a essi.
  static const List<Color> siriGlow = [
    Color(0xFF4F7BFF), // blu
    Color(0xFFB24CFF), // viola
    Color(0xFFFF5DA2), // rosa
    Color(0xFF39E1FF), // ciano
  ];
}
