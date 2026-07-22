import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_mobile/shared/widgets/empty_state.dart';

/// Richiesta esplicita dell'utente: "empty state illustrati" — l'icona
/// singola di prima diventa un'illustrazione (icona più grande su due
/// cerchi sfumati), con una tinta per sezione invece del solo grigio.
void main() {
  testWidgets('mostra titolo, messaggio e icona con la tinta indicata',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.sticky_note_2_outlined,
            color: Colors.orange,
            title: 'Nessuna nota ancora',
            message: 'Crea la tua prima nota.',
          ),
        ),
      ),
    );

    expect(find.text('Nessuna nota ancora'), findsOneWidget);
    expect(find.text('Crea la tua prima nota.'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.sticky_note_2_outlined));
    expect(icon.color, Colors.orange);
  });

  testWidgets('senza un colore indicato usa il primario del tema',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
            colorScheme: const ColorScheme.light(primary: Colors.teal)),
        home: const Scaffold(
          body: EmptyState(
            icon: Icons.search_off,
            title: 'Nessun risultato',
            message: 'Prova con un\'altra parola.',
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.search_off));
    expect(icon.color, Colors.teal);
  });
}
