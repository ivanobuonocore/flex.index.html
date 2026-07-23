import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/task/presentation/task_list_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_task_repository.dart';
import '../../../support/fake_workspace_sharing_repository.dart';

/// Conferma su swipe-to-delete (richiesta esplicita dell'utente: "conferma
/// su swipe-to-delete per elementi non banali") — un'Attività cancellata non
/// è recuperabile con un tocco dopo lo swipe.
void main() {
  const workspaceId = 'w1';
  final task = Task(
    id: 't1',
    workspaceId: workspaceId,
    title: 'Pagare bolletta',
    status: TaskStatus.todo,
    priority: TaskPriority.medium,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeTaskRepository fakeRepository,
  ) {
    // `TaskListScreen` osserva `currentMemberRoleProvider` (permessi
    // granulari sui Workspace condivisi): senza queste due dipendenze
    // (mai esercitate in questi test, che riguardano un Workspace personale)
    // fallirebbe tentando di leggere `Supabase.instance` non inizializzato.
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(fakeRepository),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          workspaceSharingRepositoryProvider
              .overrideWithValue(FakeWorkspaceSharingRepository()),
        ],
        child: const MaterialApp(
          home: TaskListScreen(workspaceId: workspaceId),
        ),
      ),
    );
  }

  testWidgets('scorrere un\'attività chiede conferma prima di cancellarla',
      (tester) async {
    final fakeRepository = FakeTaskRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([task]);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Eliminare questa attività?'), findsOneWidget);
    expect(fakeRepository.lastDeletedId, isNull);

    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(fakeRepository.lastDeletedId, 't1');
  });

  testWidgets('annullare la conferma non cancella l\'attività', (tester) async {
    final fakeRepository = FakeTaskRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([task]);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(fakeRepository.lastDeletedId, isNull);
    expect(find.text('Pagare bolletta'), findsOneWidget);
  });

  testWidgets(
      'completare un\'attività innesca la micro-animazione di conferma (richiesta '
      'esplicita dell\'utente)', (tester) async {
    final fakeRepository = FakeTaskRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([task]);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(fakeRepository.lastUpdated?.status, TaskStatus.done);

    // Il repository fittizio non riemette da solo: simula il round-trip
    // realtime, stessa convenzione già usata altrove in questi test.
    fakeRepository.emit([task.copyWith(status: TaskStatus.done)]);
    await tester.pump();
    // Il finder va ristretto al `ScaleTransition` che avvolge il Checkbox: lo
    // Scaffold ha anche un FloatingActionButton, la cui comparsa/scomparsa è
    // anch'essa animata con un proprio `ScaleTransition` interno a Flutter.
    final scaleFinder = find.ancestor(
      of: find.byType(Checkbox),
      matching: find.byType(ScaleTransition),
    );

    // Durante il pop la scala supera 1.0 in almeno uno dei fotogrammi
    // intermedi (non si verifica un singolo istante preciso: il timing esatto
    // di un `AnimationController` nel test binding non è garantito al
    // millisecondo) — poi si assesta di nuovo esattamente a 1.0 a fine
    // animazione.
    var sawScaleAboveOne = false;
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (tester.widget<ScaleTransition>(scaleFinder).scale.value > 1.0) {
        sawScaleAboveOne = true;
      }
    }
    expect(sawScaleAboveOne, isTrue);

    await tester.pumpAndSettle();
    final scaleAfter = tester.widget<ScaleTransition>(scaleFinder);
    expect(scaleAfter.scale.value, 1.0);
  });
}
