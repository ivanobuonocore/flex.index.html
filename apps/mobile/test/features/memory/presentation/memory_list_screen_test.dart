import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/memory/presentation/memory_list_screen.dart';

import '../../../support/fake_memory_repository.dart';

void main() {
  final memory = Memory(
    id: 'm1',
    content: 'Preferisce il caffè la mattina',
    level: MemoryLevel.global,
    origin: MemoryOrigin.ai,
    userId: 'u1',
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
        child: const MaterialApp(home: MemoryListScreen()),
      ),
    );
  }

  testWidgets('mostra il messaggio vuoto senza memorie', (tester) async {
    final fakeRepository = FakeMemoryRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit(const []);
    await tester.pumpAndSettle();

    expect(find.text('Nessuna memoria ancora'), findsOneWidget);
  });

  testWidgets('mostra il contenuto di ogni memoria', (tester) async {
    final fakeRepository = FakeMemoryRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([memory]);
    await tester.pumpAndSettle();

    expect(find.text('Preferisce il caffè la mattina'), findsOneWidget);
  });

  testWidgets('scorrere una memoria chiede conferma prima di cancellarla',
      (tester) async {
    final fakeRepository = FakeMemoryRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([memory]);
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
