import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_mobile/shared/utils/undoable_delete.dart';

/// "Annulla su eliminazioni" (integrazione richiesta esplicitamente): un
/// timer posticipa l'eliminazione reale, uno SnackBar con l'azione "Annulla"
/// la può cancellare prima che scada.
void main() {
  testWidgets('senza toccare Annulla, dopo il ritardo esegue onConfirmed',
      (tester) async {
    var confirmed = false;
    var undone = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => scheduleUndoableDelete(
                context,
                message: 'Attività eliminata.',
                delay: const Duration(milliseconds: 200),
                onConfirmed: () => confirmed = true,
                onUndo: () => undone = true,
              ),
              child: const Text('Apri'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri'));
    await tester.pump();

    expect(find.text('Attività eliminata.'), findsOneWidget);
    expect(find.text('Annulla'), findsOneWidget);
    expect(confirmed, isFalse);

    await tester.pump(const Duration(milliseconds: 250));

    expect(confirmed, isTrue);
    expect(undone, isFalse);
  });

  testWidgets(
      'toccare Annulla prima della scadenza esegue onUndo, mai onConfirmed',
      (tester) async {
    var confirmed = false;
    var undone = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => scheduleUndoableDelete(
                context,
                message: 'Attività eliminata.',
                // Più lungo del tempo di comparsa animata dello SnackBar (i
                // due pump qui sotto), altrimenti il timer scadrebbe prima
                // di riuscire a toccare "Annulla".
                delay: const Duration(milliseconds: 1000),
                onConfirmed: () => confirmed = true,
                onUndo: () => undone = true,
              ),
              child: const Text('Apri'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri'));
    await tester.pump();
    // Lascia completare l'animazione di comparsa dello SnackBar, altrimenti
    // "Annulla" può risultare temporaneamente fuori dai limiti del render
    // tree e il tocco non lo raggiunge.
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Annulla'));
    await tester.pump();

    // Passato oltre il ritardo originale: onConfirmed non deve mai scattare,
    // il timer è stato cancellato al tocco di "Annulla".
    await tester.pump(const Duration(milliseconds: 1000));

    expect(undone, isTrue);
    expect(confirmed, isFalse);
  });
}
