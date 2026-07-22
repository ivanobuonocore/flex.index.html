import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/export/presentation/data_export_sheet.dart';

import '../../../support/fake_export_data_repositories.dart';

void main() {
  testWidgets(
      'mostra il conteggio dei caratteri e i pulsanti dopo la generazione',
      (tester) async {
    final workspace = Workspace(
      id: 'w1',
      ownerId: 'u1',
      name: 'Casa',
      icon: 'home',
      status: WorkspaceStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceRepositoryProvider
              .overrideWithValue(FakeInstantWorkspaceRepository([workspace])),
          noteRepositoryProvider
              .overrideWithValue(FakeInstantNoteRepository(const {})),
          taskRepositoryProvider
              .overrideWithValue(FakeInstantTaskRepository(const {})),
          documentRepositoryProvider
              .overrideWithValue(FakeInstantDocumentRepository(const {})),
          calendarEventRepositoryProvider
              .overrideWithValue(FakeInstantCalendarEventRepository(const {})),
          memoryRepositoryProvider
              .overrideWithValue(FakeInstantMemoryRepository()),
          transactionRepositoryProvider
              .overrideWithValue(FakeInstantTransactionRepository(const [])),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => ElevatedButton(
              onPressed: () => showDataExportSheet(context, ref),
              child: const Text('Apri'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    expect(find.text('Esporta i miei dati'), findsOneWidget);
    expect(find.textContaining('caratteri pronti'), findsOneWidget);
    expect(find.text('Copia negli appunti'), findsOneWidget);
    expect(find.text('Invia via email'), findsOneWidget);
  });
}
