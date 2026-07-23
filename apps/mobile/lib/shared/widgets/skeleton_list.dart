import 'package:flutter/material.dart';
import 'package:pip_design_system/pip_design_system.dart';

/// Segnaposto "scheletro" per una lista in caricamento (richiesta esplicita
/// dell'utente: "skeleton loading nelle liste") — righe pulsanti che
/// anticipano la forma del contenuto reale, al posto di uno spinner centrato
/// che non dice nulla su cosa sta per arrivare.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  // Un giro continuo (non `reverse: true`): uno shimmer sweep tipico
  // attraversa sempre nella stessa direzione, non va avanti e indietro
  // (redesign estetico — richiesta esplicita dell'utente: "abbellimenti
  // stilistici").
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: widget.itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _SkeletonTile(shimmer: _controller),
    );
  }
}

/// Riga segnaposto con un vero effetto "shimmer" — una banda di luce
/// diagonale che attraversa la riga, al posto della semplice dissolvenza di
/// opacità di prima. `ShaderMask` con `BlendMode.srcATop`: il gradiente si
/// applica sopra le forme segnaposto mantenendone la trasparenza, stesso
/// principio del pacchetto `shimmer` più diffuso — qui senza aggiungere una
/// dipendenza in più per un solo effetto.
class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({required this.shimmer});

  final Animation<double> shimmer;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final base = onSurface.withOpacity(0.08);
    final highlight = onSurface.withOpacity(0.20);

    final tile = Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: base),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    height: 12,
                    width: 140,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          // La banda di luce scorre da sinistra a destra e oltre i bordi
          // (coordinate di Alignment da -1.3 a ~1.7): esce completamente di
          // scena prima di ripartire da capo, senza uno scatto visibile a
          // ogni giro.
          final sweep = shimmer.value * 3 - 1;
          return LinearGradient(
            begin: Alignment(sweep - 0.3, 0),
            end: Alignment(sweep + 0.3, 0),
            colors: [base, highlight, base],
          ).createShader(bounds);
        },
        child: child,
      ),
      child: tile,
    );
  }
}
