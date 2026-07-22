import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/export/application/data_export_controller.dart';

import '../../../support/fake_export_data_repositories.dart';

void main() {
  test(
      'generate() aggrega Note/Task/Documenti/Promemoria/Memoria per '
      'Workspace più Transazioni e Memoria globale in un unico JSON', () async {
    final workspace = Workspace(
      id: 'w1',
      ownerId: 'u1',
      name: 'Casa',
      icon: 'home',
      status: WorkspaceStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final note = Note(
      id: 'n1',
      workspaceId: 'w1',
      title: 'Lista spesa',
      content: 'Latte, pane',
      updatedAt: DateTime.utc(2026, 6, 1),
    );
    final task = Task(
      id: 't1',
      workspaceId: 'w1',
      title: 'Pagare bolletta',
      status: TaskStatus.todo,
      priority: TaskPriority.high,
      createdAt: DateTime.utc(2026, 6, 1),
    );
    final document = Document(
      id: 'd1',
      workspaceId: 'w1',
      name: 'scontrino.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 1024,
      storagePath: 'w1/d1',
      hash: 'abc',
      uploadedAt: DateTime.utc(2026, 6, 1),
    );
    final event = CalendarEvent(
      id: 'e1',
      workspaceId: 'w1',
      title: 'Dentista',
      startsAt: DateTime.utc(2026, 7, 1, 10),
      durationMinutes: 30,
      createdAt: DateTime.utc(2026, 6, 1),
    );
    final workspaceMemory = Memory(
      id: 'm1',
      content: 'Preferisce il dentista del centro',
      level: MemoryLevel.workspace,
      origin: MemoryOrigin.user,
      workspaceId: 'w1',
      updatedAt: DateTime.utc(2026, 6, 1),
    );
    final globalMemory = Memory(
      id: 'm2',
      content: 'Si chiama Ivano',
      level: MemoryLevel.global,
      origin: MemoryOrigin.ai,
      userId: 'u1',
      updatedAt: DateTime.utc(2026, 6, 1),
    );
    final transaction = Transaction(
      id: 'tr1',
      workspaceId: 'w1',
      type: TransactionType.expense,
      description: 'Barbiere',
      amountCents: 2300,
      occurredAt: DateTime.utc(2026, 6, 15),
      status: TransactionStatus.confirmed,
      createdAt: DateTime.utc(2026, 6, 15),
    );

    final container = ProviderContainer(overrides: [
      workspaceRepositoryProvider
          .overrideWithValue(FakeInstantWorkspaceRepository([workspace])),
      noteRepositoryProvider.overrideWithValue(FakeInstantNoteRepository({
        'w1': [note]
      })),
      taskRepositoryProvider.overrideWithValue(FakeInstantTaskRepository({
        'w1': [task]
      })),
      documentRepositoryProvider
          .overrideWithValue(FakeInstantDocumentRepository({
        'w1': [document]
      })),
      calendarEventRepositoryProvider
          .overrideWithValue(FakeInstantCalendarEventRepository({
        'w1': [event]
      })),
      memoryRepositoryProvider.overrideWithValue(FakeInstantMemoryRepository(
        global: [globalMemory],
        byWorkspace: {
          'w1': [workspaceMemory]
        },
      )),
      transactionRepositoryProvider
          .overrideWithValue(FakeInstantTransactionRepository([transaction])),
    ]);
    addTearDown(container.dispose);

    await container.read(dataExportControllerProvider.notifier).generate();

    final json = container.read(dataExportControllerProvider).value;
    expect(json, isNotNull);

    final decoded = jsonDecode(json!) as Map<String, dynamic>;
    expect(decoded['exportedAt'], isNotNull);

    final workspaces = decoded['workspaces'] as List;
    expect(workspaces, hasLength(1));
    final workspaceJson = workspaces.first as Map<String, dynamic>;
    expect(workspaceJson['name'], 'Casa');
    expect((workspaceJson['notes'] as List).single['title'], 'Lista spesa');
    expect((workspaceJson['tasks'] as List).single['title'], 'Pagare bolletta');
    expect(
        (workspaceJson['documents'] as List).single['name'], 'scontrino.jpg');
    expect((workspaceJson['reminders'] as List).single['title'], 'Dentista');
    expect((workspaceJson['memories'] as List).single['content'],
        'Preferisce il dentista del centro');

    final transactions = decoded['transactions'] as List;
    expect(transactions.single['description'], 'Barbiere');
    expect(transactions.single['amountCents'], 2300);

    final globalMemories = decoded['globalMemories'] as List;
    expect(globalMemories.single['content'], 'Si chiama Ivano');
  });

  test('generate() con nessun Workspace produce un export vuoto ma valido',
      () async {
    final container = ProviderContainer(overrides: [
      workspaceRepositoryProvider
          .overrideWithValue(FakeInstantWorkspaceRepository(const [])),
      noteRepositoryProvider
          .overrideWithValue(FakeInstantNoteRepository(const {})),
      taskRepositoryProvider
          .overrideWithValue(FakeInstantTaskRepository(const {})),
      documentRepositoryProvider
          .overrideWithValue(FakeInstantDocumentRepository(const {})),
      calendarEventRepositoryProvider
          .overrideWithValue(FakeInstantCalendarEventRepository(const {})),
      memoryRepositoryProvider.overrideWithValue(FakeInstantMemoryRepository()),
      transactionRepositoryProvider
          .overrideWithValue(FakeInstantTransactionRepository(const [])),
    ]);
    addTearDown(container.dispose);

    await container.read(dataExportControllerProvider.notifier).generate();

    final json = container.read(dataExportControllerProvider).value;
    final decoded = jsonDecode(json!) as Map<String, dynamic>;
    expect(decoded['workspaces'], isEmpty);
    expect(decoded['transactions'], isEmpty);
    expect(decoded['globalMemories'], isEmpty);
  });
}
