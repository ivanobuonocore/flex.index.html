import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/main.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_chat_repository.dart';
import '../../../support/fake_document_repository.dart';
import '../../../support/fake_message_repository.dart';
import '../../../support/fake_task_repository.dart';
import '../../../support/fake_transaction_repository.dart';
import '../../../support/fake_workspace_repository.dart';

/// Verifica il cuore della Slice 7B ("Chat unica" — richiesta esplicita
/// dell'utente): la Home è direttamente l'unica conversazione, con la
/// striscia "Sezioni" sempre visibile in testa, non un elenco di chat da
/// scegliere.
void main() {
  testWidgets(
      'Home Chat: mostra le sezioni fisse e riusa la Chat unica esistente',
      (tester) async {
    final fakeAuth = FakeAuthRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeChat = FakeChatRepository();
    final fakeMessage = FakeMessageRepository();
    final fakeTask = FakeTaskRepository();
    final fakeDocument = FakeDocumentRepository();
    final fakeTransaction = FakeTransactionRepository();
    addTearDown(fakeAuth.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeChat.dispose);
    addTearDown(fakeMessage.dispose);
    addTearDown(fakeTask.dispose);
    addTearDown(fakeDocument.dispose);
    addTearDown(fakeTransaction.dispose);

    final user = User(
      id: 'u1',
      email: 'ada@pip.app',
      name: 'Ada',
      plan: UserPlan.free,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final chat = Chat(
      id: 'c1',
      ownerId: 'u1',
      title: 'Assistente',
      aiModel: 'claude-sonnet-5',
      status: ChatStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final sections = [
      for (final category in SystemWorkspaceCategory.all)
        Workspace(
          id: 'w-$category',
          ownerId: 'u1',
          name: category,
          icon: 'folder',
          status: WorkspaceStatus.active,
          createdAt: DateTime.utc(2026, 1, 1),
          category: category,
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          chatRepositoryProvider.overrideWithValue(fakeChat),
          messageRepositoryProvider.overrideWithValue(fakeMessage),
          taskRepositoryProvider.overrideWithValue(fakeTask),
          documentRepositoryProvider.overrideWithValue(fakeDocument),
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
        ],
        child: const PipApp(),
      ),
    );

    fakeAuth.emit(user);
    await tester.pump();
    fakeWorkspace.emit(sections);
    fakeChat.emit([chat]);
    await tester.pump();
    fakeMessage.emit(const []);
    fakeTask.emit(const []);
    fakeDocument.emit(const []);
    fakeTransaction.emit(const []);
    await tester.pumpAndSettle();

    // Non deve mai comparire un pulsante "+"/crea chat: la Chat è unica.
    expect(find.byIcon(Icons.add), findsNothing);

    // La striscia "Sezioni" mostra le 4 sezioni fisse, sempre visibile.
    for (final category in SystemWorkspaceCategory.all) {
      expect(find.text(category), findsOneWidget);
    }

    // Nessun messaggio ancora: l'unica conversazione mostra l'invito a scrivere.
    expect(
      find.textContaining('Scrivi il primo messaggio'),
      findsOneWidget,
    );
  });
}
