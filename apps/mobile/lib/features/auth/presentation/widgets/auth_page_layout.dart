import 'package:flutter/material.dart';
import 'package:pip_design_system/pip_design_system.dart';

/// Cornice condivisa delle schermate di autenticazione.
///
/// Rende riconoscibile l'ingresso in PIP senza duplicare la stessa gerarchia
/// visiva fra login e registrazione. Il contenuto del form resta di competenza
/// delle singole schermate.
class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({required this.form, super.key});

  final Widget form;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withOpacity(isDark ? 0.16 : 0.08),
                    Theme.of(context).scaffoldBackgroundColor,
                    colorScheme.secondary.withOpacity(isDark ? 0.13 : 0.06),
                  ],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _ProductIntroduction(isDark: isDark),
                              ),
                              const SizedBox(width: AppSpacing.xxl),
                              SizedBox(
                                width: 420,
                                child: _FormPanel(form: form),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ProductIntroduction(
                                isDark: isDark,
                                compact: true,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _FormPanel(form: form),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadii.cardPremiumRadius,
        border: Border.all(
          color: (isDark ? AppColors.hairlineDark : AppColors.hairlineLight),
        ),
        boxShadow: AppShadows.card(isDark: isDark),
      ),
      child: form,
    );
  }
}

class _ProductIntroduction extends StatelessWidget {
  const _ProductIntroduction({required this.isDark, this.compact = false});

  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.heroGradient),
            borderRadius: AppRadii.pillRadius,
            boxShadow: AppShadows.glow(
              color: colorScheme.primary,
              isDark: isDark,
            ),
          ),
          child: Text(
            'PIP  •  PERSONAL INTELLIGENCE PLATFORM',
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          compact
              ? 'Il tuo spazio,\npiù intelligente.'
              : 'Uno spazio per\npensare meglio.',
          style: compact ? AppTypography.heading1 : AppTypography.display,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Riunisci progetti, idee e attività. PIP conserva il contesto e ti aiuta a trasformarlo in azione.',
          style: AppTypography.body.copyWith(
            color: colorScheme.onSurface.withOpacity(0.68),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: AppSpacing.xl),
          const _ProductPoint(
            icon: Icons.auto_awesome_outlined,
            title: 'Assistente nel contesto',
            description: 'Una chat che conosce i tuoi workspace.',
          ),
          const SizedBox(height: AppSpacing.md),
          const _ProductPoint(
            icon: Icons.account_tree_outlined,
            title: 'Tutto connesso',
            description: 'Note, task e documenti nello stesso posto.',
          ),
          const SizedBox(height: AppSpacing.md),
          const _ProductPoint(
            icon: Icons.today_outlined,
            title: 'Focus su oggi',
            description: 'Le priorità chiare, quando servono.',
          ),
        ],
      ],
    );
  }
}

class _ProductPoint extends StatelessWidget {
  const _ProductPoint({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: AppRadii.standardRadius,
          ),
          child: Icon(icon, color: colorScheme.primary, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: AppTypography.caption.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.62),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
