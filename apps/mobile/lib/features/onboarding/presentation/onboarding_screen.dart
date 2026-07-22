import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';

import '../../auth/application/auth_controller.dart';

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const _slides = [
  _OnboardingSlide(
    icon: Icons.chat_bubble_rounded,
    title: 'Tutto parte dalla Chat',
    description: 'Scrivi una spesa, un promemoria, una nota o un elemento da '
        'aggiungere a una lista: l\'assistente li smista da solo nella '
        'sezione giusta.',
  ),
  _OnboardingSlide(
    icon: Icons.space_dashboard_outlined,
    title: 'I tuoi Spazi, sempre organizzati',
    description:
        'Bilancio, Note, Attività, Documenti e Appuntamenti sono sempre a '
        'un tocco di distanza, dalla striscia "Sezioni" sopra la Chat.',
  ),
  _OnboardingSlide(
    icon: Icons.psychology_outlined,
    title: 'L\'AI ricorda, tu decidi',
    description: 'L\'assistente può ricordare informazioni utili, ma ogni '
        'transazione o promemoria che suggerisce resta in attesa finché non '
        'lo confermi tu.',
  ),
];

/// Onboarding leggero al primo accesso (richiesta esplicita dell'utente):
/// 3 schermate scorrevoli con un pulsante "Salta" sempre visibile — non un
/// passaggio obbligato, solo un'introduzione rapida ai pilastri dell'app.
/// Mostrata una sola volta (`User.onboardingCompleted`, persistito lato
/// identity provider come la preferenza di tema) e mai più dopo averla
/// completata o saltata.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(authControllerProvider.notifier).completeOnboarding();
    // Nessuna navigazione esplicita: il redirect di GoRouter (basato su
    // `User.onboardingCompleted`) porta da solo a `/chat` appena
    // `sessionControllerProvider` riflette il nuovo valore.
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _page == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Salta'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _page = index),
                children: [
                  for (final slide in _slides) _SlideView(slide: slide),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    width: i == _page ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.heroGradient.first
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLastPage
                      ? _finish
                      : () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                  child: Text(isLastPage ? 'Inizia' : 'Avanti'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: AppColors.heroGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: AppShadows.glow(
                color: AppColors.heroGradient.first,
                isDark: isDark,
              ),
            ),
            child: Icon(slide.icon, size: 60, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            slide.title,
            style: AppTypography.heading2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            slide.description,
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
