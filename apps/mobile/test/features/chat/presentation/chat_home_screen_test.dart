import 'dart:async';

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

  testWidgets('Il saluto scrive il nome dell\'utente con la maiuscola',
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

    // Il nome è salvato in minuscolo (es. digitato così in registrazione):
    // il saluto deve comunque mostrarlo con l'iniziale maiuscola.
    final user = User(
      id: 'u1',
      email: 'ivano@pip.app',
      name: 'ivano',
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
    fakeWorkspace.emit(const []);
    fakeChat.emit([chat]);
    await tester.pump();
    fakeMessage.emit(const []);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
          RegExp(r'^(Buongiorno|Buon pomeriggio|Buonasera), Ivano$')),
      findsOneWidget,
    );
  });

  testWidgets(
      'la bolla "sta scrivendo" compare mentre l\'invio è in corso e scompare dopo',
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
    fakeWorkspace.emit(const []);
    fakeChat.emit([chat]);
    await tester.pump();
    fakeMessage.emit(const []);
    await tester.pumpAndSettle();

    final pendingSend = Completer<void>();
    fakeMessage.pendingSend = pendingSend;

    await tester.enterText(find.byType(TextField), 'Ciao');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.textContaining('sta scrivendo'), findsOneWidget);

    pendingSend.complete();
    await tester.pumpAndSettle();

    expect(find.textContaining('sta scrivendo'), findsNothing);
  });

  testWidgets(
      'il messaggio dell\'utente appare subito, senza aspettare Realtime, '
      'e non si duplica quando arriva quello reale', (tester) async {
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
    fakeWorkspace.emit(const []);
    fakeChat.emit([chat]);
    await tester.pump();
    fakeMessage.emit(const []);
    await tester.pumpAndSettle();

    final pendingSend = Completer<void>();
    fakeMessage.pendingSend = pendingSend;

    await tester.enterText(find.byType(TextField), 'Ciao subito');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // Compare subito, prima che il repository fittizio abbia anche solo
    // risolto sendMessage (pendingSend non è ancora completato): non aspetta
    // il giro di andata/ritorno di Realtime.
    expect(find.text('Ciao subito'), findsOneWidget);

    // Il messaggio reale arriva via Realtime (come farebbe la sottoscrizione
    // Postgres) mentre l'eco locale è ancora visibile: non deve duplicarsi.
    fakeMessage.emit([
      Message(
        id: 'm1',
        chatId: 'c1',
        role: MessageRole.user,
        content: 'Ciao subito',
        timestamp: DateTime.now(),
      ),
    ]);
    await tester.pump();

    expect(find.text('Ciao subito'), findsOneWidget);

    pendingSend.complete();
    await tester.pumpAndSettle();

    expect(find.text('Ciao subito'), findsOneWidget);
    expect(find.textContaining('sta scrivendo'), findsNothing);
  });
}
