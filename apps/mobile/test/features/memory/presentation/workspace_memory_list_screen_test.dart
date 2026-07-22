import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/memory/presentation/workspace_memory_list_screen.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_memory_repository.dart';

void main() {
  const workspaceId = 'w1';
  final memory = Memory(
    id: 'm1',
    content: 'Il contratto scade a marzo',
    level: MemoryLevel.workspace,
    origin: MemoryOrigin.user,
    workspaceId: workspaceId,
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeMemoryRepository fakeRepository,
  ) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: const MaterialApp(
          home: WorkspaceMemoryListScreen(workspaceId: workspaceId),
        ),
      ),
    );
  }

  testWidgets('mostra il messaggio vuoto senza memorie', (tester) async {
    final fakeRepository = FakeMemoryRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emitWorkspace(const []);
    await tester.pumpAndSettle();

    expect(find.text('Nessuna memoria ancora'), findsOneWidget);
  });

  testWidgets('mostra il contenuto di ogni memoria', (tester) async {
    final fakeRepository = FakeMemoryRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emitWorkspace([memory]);
    await tester.pumpAndSettle();

    expect(find.text('Il contratto scade a marzo'), findsOneWidget);
  });

  testWidgets(
      'il pulsante + apre un dialog che crea una memoria tramite il repository',
      (tester) async {
    final fakeRepository = FakeMemoryRepository();
    addTearDown(fakeRepository.dispose);
    fakeRepository.createWorkspaceResult = Result.ok(memory);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emitWorkspace(const []);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Nuova informazione');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(fakeRepository.lastCreatedWorkspaceId, workspaceId);
    expect(fakeRepository.lastCreatedContent, 'Nuova informazione');
  });

  testWidgets('scorrere una memoria chiede conferma prima di cancellarla',
      (tester) async {
    final fakeRepository = FakeMemoryRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emitWorkspace([memory]);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Eliminare questa memoria?'), findsOneWidget);
    expect(fakeRepository.lastDeletedId, isNull);

    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(fakeRepository.lastDeletedId, 'm1');
  });
}
