import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_mobile/shared/widgets/coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'un coach mark non ancora visto mostra il messaggio, sopra il figlio',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoachMark(
            id: 'test_id',
            message: 'Prova questa funzione',
            child: Text('Contenuto'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Prova questa funzione'), findsOneWidget);
    expect(find.text('Contenuto'), findsOneWidget);
  });

  testWidgets('un coach mark già visto mostra solo il figlio, senza messaggio',
      (tester) async {
    SharedPreferences.setMockInitialValues({'coach_mark_seen_test_id': true});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoachMark(
            id: 'test_id',
            message: 'Prova questa funzione',
            child: Text('Contenuto'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Prova questa funzione'), findsNothing);
    expect(find.text('Contenuto'), findsOneWidget);
  });

  testWidgets(
      'toccare la chiusura nasconde il messaggio e lo ricorda per le volte successive',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoachMark(
            id: 'test_id',
            message: 'Prova questa funzione',
            child: Text('Contenuto'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Prova questa funzione'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('Prova questa funzione'), findsNothing);
    expect(find.text('Contenuto'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('coach_mark_seen_test_id'), isTrue);
  });
}
