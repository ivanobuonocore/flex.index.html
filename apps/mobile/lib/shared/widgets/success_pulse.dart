import 'package:flutter/material.dart';

/// Micro-animazione di conferma (richiesta esplicita dell'utente: "migliorie
/// grafiche... micro-animazioni di conferma"): quando [play] passa da falso a
/// vero, il figlio fa un piccolo "pop" (scala oltre 1 e torna a 1) — un
/// feedback visivo più vivo per un'azione di conferma (completare
/// un'Attività, confermare una Transazione), senza introdurre alcuna
/// dipendenza esterna. Il figlio resta sempre visibile: l'animazione non
/// nasconde né sostituisce nulla, aggiunge solo movimento.
class SuccessPulse extends StatefulWidget {
  const SuccessPulse({super.key, required this.play, required this.child});

  final bool play;
  final Widget child;

  @override
  State<SuccessPulse> createState() => _SuccessPulseState();
}

class _SuccessPulseState extends State<SuccessPulse>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final _scale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50),
    TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50),
  ]).animate(_controller);

  @override
  void didUpdateWidget(covariant SuccessPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
