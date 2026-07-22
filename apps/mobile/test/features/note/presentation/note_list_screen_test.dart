import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/note/presentation/note_list_screen.dart';

import '../../../support/fake_note_repository.dart';

/// Tag sulle Note resi visibili (richiesta esplicita dell'utente: erano già
/// modellati nel dominio/persistiti dal repository, ma nessuna schermata li
/// mostrava o permetteva di filtrare per tag).
void main() {
  const workspaceId = 'w1';
  final workNote = Note(
    id: 'n1',
    workspaceId: workspaceId,
    title: 'Riunione',
    content: 'contenuto',
    tags: const ['lavoro'],
    updatedAt: DateTime.utc(2026, 1, 1),
  );
  final personalNote = Note(
    id: 'n2',
    workspaceId: workspaceId,
    title: 'Lista spesa',
    content: 'contenuto',
    tags: const ['personale'],
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeNoteRepository fakeRepository,
  ) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(fakeRepository)],
        child: const MaterialApp(
          home: NoteListScreen(workspaceId: workspaceId),
        ),
      ),
    );
  }

  testWidgets('mostra i tag di ogni nota come pillole', (tester) async {
    final fakeRepository = FakeNoteRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([workNote, personalNote]);
    await tester.pumpAndSettle();

    expect(find.text('Riunione'), findsOneWidget);
    expect(find.text('Lista spesa'), findsOneWidget);
    expect(find.text('lavoro'), findsWidgets);
    expect(find.text('personale'), findsWidgets);
  });

  testWidgets('selezionare un tag nella striscia filtra l\'elenco',
      (tester) async {
    final fakeRepository = FakeNoteRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([workNote, personalNote]);
    await tester.pumpAndSettle();

    // Il FilterChip "lavoro" compare sia nella striscia di filtro sia come
    // pillola sulla nota: prendiamo il primo (la striscia è sopra l'elenco).
    await tester.tap(find.text('lavoro').first);
    await tester.pumpAndSettle();

    expect(find.text('Riunione'), findsOneWidget);
    expect(find.text('Lista spesa'), findsNothing);

    // Toccando di nuovo lo stesso tag il filtro si toglie.
    await tester.tap(find.text('lavoro').first);
    await tester.pumpAndSettle();

    expect(find.text('Riunione'), findsOneWidget);
    expect(find.text('Lista spesa'), findsOneWidget);
  });

  testWidgets('scorrere una nota chiede conferma prima di cancellarla',
      (tester) async {
    final fakeRepository = FakeNoteRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([workNote]);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Eliminare questa nota?'), findsOneWidget);
    expect(fakeRepository.lastDeletedId, isNull);

    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(fakeRepository.lastDeletedId, 'n1');
  });
}
