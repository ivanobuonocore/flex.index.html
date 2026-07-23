import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_mobile/shared/widgets/success_pulse.dart';

void main() {
  testWidgets('il figlio resta sempre visibile, con o senza animazione',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SuccessPulse(play: false, child: Text('Fatto')),
      ),
    );

    expect(find.text('Fatto'), findsOneWidget);
  });

  testWidgets(
      'quando play passa da falso a vero il figlio si scala (pop) e poi torna a 1.0',
      (tester) async {
    var play = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              SuccessPulse(play: play, child: const Text('Fatto')),
              TextButton(
                onPressed: () => setState(() => play = true),
                child: const Text('Attiva'),
              ),
            ],
          ),
        ),
      ),
    );

    final scaleBefore =
        tester.widget<ScaleTransition>(find.byType(ScaleTransition));
    expect(scaleBefore.scale.value, 1.0);

    await tester.tap(find.text('Attiva'));
    await tester.pump();
    // A metà dell'animazione (weight 50/50: scala oltre 1.0 nella prima metà).
    await tester.pump(const Duration(milliseconds: 150));
    final scaleMid =
        tester.widget<ScaleTransition>(find.byType(ScaleTransition));
    expect(scaleMid.scale.value, greaterThan(1.0));

    // A fine animazione torna esattamente a 1.0.
    await tester.pumpAndSettle();
    final scaleAfter =
        tester.widget<ScaleTransition>(find.byType(ScaleTransition));
    expect(scaleAfter.scale.value, 1.0);
  });

  testWidgets('non riparte se play resta vero (solo sul fronte falso->vero)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SuccessPulse(play: true, child: Text('Fatto')),
      ),
    );
    await tester.pumpAndSettle();

    // `play` è già vero al primo build: nessun fronte di salita, quindi
    // l'animazione non è mai partita e la scala resta 1.0 (non un pop
    // "in corso" per sempre).
    final scale = tester.widget<ScaleTransition>(find.byType(ScaleTransition));
    expect(scale.scale.value, 1.0);
  });
}
