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
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

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
      itemBuilder: (context, index) => _SkeletonTile(pulse: _controller),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final color = base.withOpacity(0.06 + pulse.value * 0.06);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(radius: 18, backgroundColor: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        height: 12,
                        width: 140,
                        decoration: BoxDecoration(
                          color: color,
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
      },
    );
  }
}
