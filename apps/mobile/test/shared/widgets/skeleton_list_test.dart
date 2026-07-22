import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_mobile/shared/widgets/skeleton_list.dart';

/// Richiesta esplicita dell'utente: "skeleton loading nelle liste", al posto
/// di uno spinner centrato. `pump()` con durata limitata, non
/// `pumpAndSettle()`: l'animazione di pulsazione è indeterminata (si ripete
/// all'infinito finché il widget è a schermo), come per un
/// `CircularProgressIndicator` — stessa lezione già imparata altrove in
/// questo progetto.
void main() {
  testWidgets('mostra il numero di righe segnaposto richiesto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SkeletonList(itemCount: 4)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Card), findsNWidgets(4));
  });
}
