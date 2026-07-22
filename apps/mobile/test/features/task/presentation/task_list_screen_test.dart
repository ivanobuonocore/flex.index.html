import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/task/presentation/task_list_screen.dart';

import '../../../support/fake_task_repository.dart';

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
    return tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(fakeRepository)],
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
}
