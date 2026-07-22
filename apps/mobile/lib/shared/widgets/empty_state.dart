import 'package:flutter/material.dart';
import 'package:pip_design_system/pip_design_system.dart';

/// Stato "Empty" (docs/product/05-design-system.md, "Stati dell'app").
///
/// Illustrazione (richiesta esplicita dell'utente: "empty state
/// illustrati"): niente immagini/asset nuovi (nessuna dipendenza aggiuntiva,
/// coerente col resto del progetto) — un'icona più grande su un doppio
/// cerchio sfumato, stessa famiglia di trattamenti "glow"/gradiente già
/// usata altrove (hero del saldo, striscia Sezioni), invece della semplice
/// icona grigia di prima.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  /// Tinta dell'illustrazione — di norma il colore della sezione (Bilancio,
  /// Note, Attività, ...), la stessa già usata per badge di categoria e
  /// striscia Sezioni. Default: colore primario del tema.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EmptyStateIllustration(icon: icon, tint: tint),
            const SizedBox(height: AppSpacing.lg),
            Text(title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyStateIllustration extends StatelessWidget {
  const _EmptyStateIllustration({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Alone esterno, ampio e molto tenue: dà profondità senza
          // disegnare un vero e proprio bordo visibile.
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  tint.withOpacity(isDark ? 0.22 : 0.14),
                  tint.withOpacity(0),
                ],
              ),
            ),
          ),
          // Disco interno con l'icona, stesso trattamento gradiente+bordo
          // sottile della striscia Sezioni.
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [tint.withOpacity(0.20), tint.withOpacity(0.08)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: tint.withOpacity(0.25)),
            ),
            child: Icon(icon, size: 34, color: tint),
          ),
        ],
      ),
    );
  }
}
