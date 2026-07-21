import 'package:flutter/material.dart';
import 'package:pip_design_system/pip_design_system.dart';

/// AppBar con gradiente "premium" (redesign estetico 2.0 — richiesta esplicita
/// dell'utente: "molto tecnologica", coerente con l'estetica di Planito).
/// Stessa famiglia cromatica del pulsante Chat in bottom nav
/// ([AppColors.siriGlow]/[AppColors.heroGradient]): le schermate principali
/// (Chat, Bilancio) condividono lo stesso linguaggio visivo, senza toccare il
/// pulsante Chat stesso (`app_shell.dart`, non modificato). Un solo widget
/// condiviso invece di duplicare la stessa decorazione in ogni schermata
/// (AGENTS.md, "Design System" — niente componenti duplicati).
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({super.key, required this.title, this.actions});

  final Widget title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AppShadows.glow(
            color: AppColors.heroGradient.first, isDark: isDark),
      ),
      child: AppBar(
        title: title,
        actions: actions,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
