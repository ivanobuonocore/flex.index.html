import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/chat/application/message_controller.dart';
import 'package:pip_mobile/features/reminder/presentation/reminder_list_screen.dart';
import 'package:pip_mobile/main.dart';
import 'package:pip_mobile/shared/widgets/loading_view.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_calendar_event_repository.dart';
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
      onboardingCompleted: true,
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

  testWidgets('toccare la sezione Appuntamenti apre direttamente il calendario',
      (tester) async {
    final fakeAuth = FakeAuthRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeChat = FakeChatRepository();
    final fakeMessage = FakeMessageRepository();
    final fakeTask = FakeTaskRepository();
    final fakeDocument = FakeDocumentRepository();
    final fakeTransaction = FakeTransactionRepository();
    final fakeCalendarEvent = FakeCalendarEventRepository();
    addTearDown(fakeAuth.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeChat.dispose);
    addTearDown(fakeMessage.dispose);
    addTearDown(fakeTask.dispose);
    addTearDown(fakeDocument.dispose);
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeCalendarEvent.dispose);

    final user = User(
      id: 'u1',
      email: 'ada@pip.app',
      name: 'Ada',
      plan: UserPlan.free,
      createdAt: DateTime.utc(2026, 1, 1),
      onboardingCompleted: true,
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
          calendarEventRepositoryProvider.overrideWithValue(fakeCalendarEvent),
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

    await tester.tap(find.text(SystemWorkspaceCategory.appuntamenti));
    await tester.pump();
    fakeCalendarEvent.emit(const []);
    await tester.pumpAndSettle();

    // Non la generica WorkspaceDetailScreen (dove il calendario sarebbe
    // raggiungibile solo con un tocco in più su "vedi tutti"), ma
    // direttamente ReminderListScreen col calendario mensile.
    expect(find.byType(ReminderListScreen), findsOneWidget);
  });

  testWidgets(
      'i badge su Appuntamenti e sul pulsante Chat mostrano i conteggi giusti',
      (tester) async {
    final fakeAuth = FakeAuthRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeChat = FakeChatRepository();
    final fakeMessage = FakeMessageRepository();
    final fakeTask = FakeTaskRepository();
    final fakeDocument = FakeDocumentRepository();
    final fakeTransaction = FakeTransactionRepository();
    final fakeCalendarEvent = FakeCalendarEventRepository();
    addTearDown(fakeAuth.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeChat.dispose);
    addTearDown(fakeMessage.dispose);
    addTearDown(fakeTask.dispose);
    addTearDown(fakeDocument.dispose);
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeCalendarEvent.dispose);

    final user = User(
      id: 'u1',
      email: 'ada@pip.app',
      name: 'Ada',
      plan: UserPlan.free,
      createdAt: DateTime.utc(2026, 1, 1),
      onboardingCompleted: true,
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
    final now = DateTime.now();
    final reminderToday = CalendarEvent(
      id: 'e1',
      workspaceId: 'w-${SystemWorkspaceCategory.appuntamenti}',
      title: 'Dentista',
      startsAt: now,
      durationMinutes: 30,
      createdAt: now,
    );
    final pendingTransaction = Transaction(
      id: 't1',
      workspaceId: 'w-${SystemWorkspaceCategory.bilancio}',
      type: TransactionType.expense,
      description: 'Suggerita dall\'AI',
      amountCents: 1000,
      occurredAt: now,
      status: TransactionStatus.pending,
      createdAt: now,
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
          calendarEventRepositoryProvider.overrideWithValue(fakeCalendarEvent),
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
    fakeTransaction.emit([pendingTransaction]);
    fakeCalendarEvent.emit([reminderToday]);
    await tester.pumpAndSettle();

    // "1" compare due volte: badge su Appuntamenti (promemoria di oggi) e
    // badge sul pulsante Chat (transazione ancora da confermare).
    expect(find.text('1'), findsNWidgets(2));
  });

  testWidgets(
      'il blocco "Oggi" mostra il prossimo impegno e le attività aperte '
      'quando presenti', (tester) async {
    final fakeAuth = FakeAuthRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeChat = FakeChatRepository();
    final fakeMessage = FakeMessageRepository();
    final fakeTask = FakeTaskRepository();
    final fakeDocument = FakeDocumentRepository();
    final fakeTransaction = FakeTransactionRepository();
    final fakeCalendarEvent = FakeCalendarEventRepository();
    addTearDown(fakeAuth.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeChat.dispose);
    addTearDown(fakeMessage.dispose);
    addTearDown(fakeTask.dispose);
    addTearDown(fakeDocument.dispose);
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeCalendarEvent.dispose);

    final user = User(
      id: 'u1',
      email: 'ada@pip.app',
      name: 'Ada',
      plan: UserPlan.free,
      createdAt: DateTime.utc(2026, 1, 1),
      onboardingCompleted: true,
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
    final now = DateTime.now();
    final eventToday = CalendarEvent(
      id: 'e1',
      workspaceId: 'w-${SystemWorkspaceCategory.appuntamenti}',
      title: 'Dentista',
      startsAt: now,
      durationMinutes: 30,
      createdAt: now,
    );
    final openTask = Task(
      id: 'task-1',
      workspaceId: 'w-${SystemWorkspaceCategory.attivita}',
      title: 'Comprare il latte',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      createdAt: now,
    );
    final doneTask = Task(
      id: 'task-2',
      workspaceId: 'w-${SystemWorkspaceCategory.attivita}',
      title: 'Fatto ieri',
      status: TaskStatus.done,
      priority: TaskPriority.medium,
      createdAt: now,
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
          calendarEventRepositoryProvider.overrideWithValue(fakeCalendarEvent),
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
    fakeTask.emit([openTask, doneTask]);
    fakeDocument.emit(const []);
    fakeTransaction.emit(const []);
    fakeCalendarEvent.emit([eventToday]);
    await tester.pumpAndSettle();

    expect(find.textContaining('Prossimo: Dentista alle'), findsOneWidget);
    expect(find.text('1 attività da fare'), findsOneWidget);
  });

  testWidgets(
      'il blocco "Oggi" non mostra nulla quando non c\'è nessun impegno, '
      'attività aperta o transazione questo mese', (tester) async {
    final fakeAuth = FakeAuthRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeChat = FakeChatRepository();
    final fakeMessage = FakeMessageRepository();
    final fakeTask = FakeTaskRepository();
    final fakeDocument = FakeDocumentRepository();
    final fakeTransaction = FakeTransactionRepository();
    final fakeCalendarEvent = FakeCalendarEventRepository();
    addTearDown(fakeAuth.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeChat.dispose);
    addTearDown(fakeMessage.dispose);
    addTearDown(fakeTask.dispose);
    addTearDown(fakeDocument.dispose);
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeCalendarEvent.dispose);

    final user = User(
      id: 'u1',
      email: 'ada@pip.app',
      name: 'Ada',
      plan: UserPlan.free,
      createdAt: DateTime.utc(2026, 1, 1),
      onboardingCompleted: true,
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
          calendarEventRepositoryProvider.overrideWithValue(fakeCalendarEvent),
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
    fakeCalendarEvent.emit(const []);
    await tester.pumpAndSettle();

    expect(find.textContaining('Prossimo:'), findsNothing);
    expect(find.textContaining('attività da fare'), findsNothing);
    expect(find.textContaining('Proiezione fine mese'), findsNothing);
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
      onboardingCompleted: true,
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
      onboardingCompleted: true,
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
      onboardingCompleted: true,
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

  testWidgets(
      'lo scroll non torna mai indietro se il messaggio dell\'assistente '
      'arriva dopo che isLoading è già tornato false', (tester) async {
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
      onboardingCompleted: true,
    );
    final chat = Chat(
      id: 'c1',
      ownerId: 'u1',
      title: 'Assistente',
      aiModel: 'claude-sonnet-5',
      status: ChatStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    // Una conversazione lunga: senza contenuto sufficiente non ci sarebbe
    // nulla da "far saltare" nello scroll.
    final messages = [
      for (var i = 0; i < 30; i++)
        Message(
          id: 'm$i',
          chatId: 'c1',
          role: i.isEven ? MessageRole.user : MessageRole.ai,
          content: 'Messaggio numero $i, abbastanza lungo da occupare più '
              'di una riga nella bolla della chat.',
          timestamp: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
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
    fakeWorkspace.emit(const []);
    fakeChat.emit([chat]);
    await tester.pump();
    fakeMessage.emit(messages);
    await tester.pumpAndSettle();

    double offsetOf() =>
        tester.widget<ListView>(find.byType(ListView)).controller!.offset;

    final offsets = <double>[offsetOf()];

    final pendingSend = Completer<void>();
    fakeMessage.pendingSend = pendingSend;

    await tester.enterText(find.byType(TextField), 'Nuovo messaggio di test');
    await tester.tap(find.byIcon(Icons.send));

    // Campiona l'offset ad ogni frame, senza pumpAndSettle (che
    // nasconderebbe proprio il tipo di salto verificato qui): prima
    // l'animazione di scroll per l'eco locale + bolla "sta scrivendo".
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      offsets.add(offsetOf());
    }

    // L'eco reale del messaggio utente arriva via Realtime.
    fakeMessage.emit([
      ...messages,
      Message(
        id: 'm-new',
        chatId: 'c1',
        role: MessageRole.user,
        content: 'Nuovo messaggio di test',
        timestamp: DateTime.utc(2026, 1, 1, 1),
      ),
    ]);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      offsets.add(offsetOf());
    }

    // L'invio HTTP termina (isLoading -> false) PRIMA che il messaggio
    // dell'assistente sia arrivato via Realtime — la sequenza temporale che
    // causava lo scatto: la bolla "sta scrivendo" non deve sparire ancora.
    pendingSend.complete();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      offsets.add(offsetOf());
    }
    expect(find.textContaining('sta scrivendo'), findsOneWidget);

    // Solo ora arriva la risposta reale dell'assistente.
    fakeMessage.emit([
      ...messages,
      Message(
        id: 'm-new',
        chatId: 'c1',
        role: MessageRole.user,
        content: 'Nuovo messaggio di test',
        timestamp: DateTime.utc(2026, 1, 1, 1),
      ),
      Message(
        id: 'm-ai-reply',
        chatId: 'c1',
        role: MessageRole.ai,
        content: 'Risposta dell\'assistente.',
        timestamp: DateTime.utc(2026, 1, 1, 1, 1),
      ),
    ]);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      offsets.add(offsetOf());
    }

    // Il cuore della verifica: lo scroll non deve mai tornare indietro in
    // modo brusco (la bolla "sta scrivendo" che sparisce prima che arrivi il
    // messaggio reale causava un salto istantaneo, senza animazione, verso
    // l'alto). Una piccola tolleranza copre solo l'arrotondamento in virgola
    // mobile tra un frame e l'altro, non un vero e proprio salto indietro.
    for (var i = 1; i < offsets.length; i++) {
      expect(
        offsets[i],
        greaterThanOrEqualTo(offsets[i - 1] - 0.5),
        reason: 'Salto indietro dello scroll tra il frame ${i - 1} '
            '(${offsets[i - 1]}) e il frame $i (${offsets[i]})',
      );
    }

    await tester.pumpAndSettle();
    expect(find.textContaining('sta scrivendo'), findsNothing);
  });

  testWidgets(
      'un timeout di sicurezza rimasto da un invio precedente non nasconde '
      'la bolla di un invio successivo ancora in corso', (tester) async {
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
      onboardingCompleted: true,
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

    // Primo invio: finisce rapidamente senza che arrivi mai una risposta
    // dell'assistente (come un fallimento silenzioso) — a isLoading->false
    // pianifica il timeout di sicurezza di 5s, che a questo punto non ha
    // ancora nulla da ripulire (nessuna bolla in corso più avanti).
    final firstPending = Completer<void>();
    fakeMessage.pendingSend = firstPending;
    await tester.enterText(find.byType(TextField), 'Primo');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    firstPending.complete();
    await tester.pump();

    // Prima che quel timeout scada, arriva un secondo invio, che deve
    // restare "in corso" più a lungo.
    await tester.pump(const Duration(seconds: 2));
    final secondPending = Completer<void>();
    fakeMessage.pendingSend = secondPending;
    await tester.enterText(find.byType(TextField), 'Secondo');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.textContaining('sta scrivendo'), findsOneWidget);

    // Oltrepassa i 5s dal PRIMO isLoading->false: il timeout "orfano"
    // scatterebbe qui se non fosse stato annullato all'inizio del secondo
    // invio — la bolla del secondo invio deve restare visibile.
    await tester.pump(const Duration(seconds: 4));
    expect(find.textContaining('sta scrivendo'), findsOneWidget);

    secondPending.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('sta scrivendo'), findsNothing);
  });

  testWidgets(
      'la lista dei messaggi non sparisce se lo stream si ricarica da capo '
      '(es. riconnessione Realtime)', (tester) async {
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
      onboardingCompleted: true,
    );
    final chat = Chat(
      id: 'c1',
      ownerId: 'u1',
      title: 'Assistente',
      aiModel: 'claude-sonnet-5',
      status: ChatStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final message = Message(
      id: 'm1',
      chatId: 'c1',
      role: MessageRole.user,
      content: 'Messaggio già mostrato',
      timestamp: DateTime.utc(2026, 1, 1),
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
    fakeMessage.emit([message]);
    await tester.pumpAndSettle();

    expect(find.text('Messaggio già mostrato'), findsOneWidget);

    // Simula una ri-sottoscrizione dello stream (es. una riconnessione del
    // canale Realtime di Supabase): il provider riparte da zero, in stato di
    // caricamento, prima di ricevere di nuovo i dati.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PipApp)),
    );
    container.invalidate(messagesProvider('c1'));
    await tester.pump();

    // Il messaggio già mostrato non deve sparire: niente spinner o schermata
    // vuota al posto della conversazione già visibile.
    expect(find.text('Messaggio già mostrato'), findsOneWidget);
    expect(find.byType(LoadingView), findsNothing);

    // E quando arrivano di nuovo i dati (stream ripristinato), tutto
    // continua a funzionare normalmente.
    fakeMessage.emit([message]);
    await tester.pumpAndSettle();
    expect(find.text('Messaggio già mostrato'), findsOneWidget);
  });

  testWidgets(
      'un aggiornamento della Chat (es. il trigger che segna l\'ultimo '
      'messaggio) non distrugge la lista messaggi né lo scroll già fatto',
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
      onboardingCompleted: true,
    );
    final chat = Chat(
      id: 'c1',
      ownerId: 'u1',
      title: 'Assistente',
      aiModel: 'claude-sonnet-5',
      status: ChatStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    // Una conversazione lunga: se `_MessagesArea` venisse ricreata da zero,
    // lo scroll tornerebbe a zero (cima della lista) invece di restare dov'era.
    final messages = [
      for (var i = 0; i < 30; i++)
        Message(
          id: 'm$i',
          chatId: 'c1',
          role: i.isEven ? MessageRole.user : MessageRole.ai,
          content: 'Messaggio numero $i, abbastanza lungo da occupare più '
              'di una riga nella bolla della chat.',
          timestamp: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
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
    fakeWorkspace.emit(const []);
    fakeChat.emit([chat]);
    await tester.pump();
    fakeMessage.emit(messages);
    await tester.pumpAndSettle();

    final offsetBefore =
        tester.widget<ListView>(find.byType(ListView)).controller!.offset;
    expect(offsetBefore, greaterThan(0));

    // `chatsProvider` riemette (come farebbe il trigger Postgres
    // `messages_touch_chat_last_message` ad ogni messaggio inviato o
    // ricevuto, aggiornando `chats.last_message_at`): `singleChatProvider` ne
    // dipende e "ricarica" di conseguenza.
    fakeChat.emit([chat]);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Non deve comparire nessuno spinner a schermo intero, e la lista (con
    // il suo scroll) deve essere rimasta esattamente la stessa istanza:
    // se `_ChatHomeBody`/`_MessagesArea` fossero stati ricreati da zero, lo
    // scroll sarebbe tornato a 0.
    expect(find.byType(LoadingView), findsNothing);
    expect(
        find.text('Messaggio numero 29, abbastanza lungo da occupare più '
            'di una riga nella bolla della chat.'),
        findsOneWidget);
    final offsetAfter =
        tester.widget<ListView>(find.byType(ListView)).controller!.offset;
    expect(offsetAfter, offsetBefore);
  });

  testWidgets(
      'un messaggio con transazioni pending mostra Conferma/Scarta inline',
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
      onboardingCompleted: true,
    );
    final chat = Chat(
      id: 'c1',
      ownerId: 'u1',
      title: 'Assistente',
      aiModel: 'claude-sonnet-5',
      status: ChatStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final pendingTransaction = Transaction(
      id: 't1',
      workspaceId: 'w-bilancio',
      type: TransactionType.expense,
      description: 'Barbiere',
      amountCents: 2300,
      occurredAt: DateTime.utc(2026, 1, 1),
      status: TransactionStatus.pending,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final aiMessage = Message(
      id: 'm1',
      chatId: 'c1',
      role: MessageRole.ai,
      content: 'Ho registrato una spesa in attesa di conferma.',
      timestamp: DateTime.utc(2026, 1, 1),
      pendingTransactionIds: const ['t1'],
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
    // `transactionsProvider(null)` è un broadcast stream: se `emit` viene
    // chiamato prima che il widget del messaggio (che lo sottoscrive per la
    // prima volta) sia stato costruito, l'evento va perso — serve un pump
    // intermedio perché il messaggio (e con esso `_PendingTransactionActions`)
    // compaia prima di emettere le transazioni.
    fakeMessage.emit([aiMessage]);
    await tester.pump();
    fakeTransaction.emit([pendingTransaction]);
    await tester.pumpAndSettle();

    expect(find.text('Barbiere'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    fakeTransaction.confirmResult = Result.ok(
      pendingTransaction.copyWith(status: TransactionStatus.confirmed),
    );
    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.pumpAndSettle();

    expect(fakeTransaction.lastConfirmedId, 't1');

    // Confermata: lo stream la riemette come `confirmed`, quindi il filtro
    // per `pending` nel widget la nasconde da sola, senza bisogno di
    // aggiornare il messaggio.
    fakeTransaction.emit(
      [pendingTransaction.copyWith(status: TransactionStatus.confirmed)],
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });

  testWidgets(
      'un messaggio con ** mostra il testo in grassetto (Text.rich), uno senza '
      'marcatori resta un Text semplice', (tester) async {
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
      onboardingCompleted: true,
    );
    final chat = Chat(
      id: 'c1',
      ownerId: 'u1',
      title: 'Assistente',
      aiModel: 'claude-sonnet-5',
      status: ChatStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final plainMessage = Message(
      id: 'm1',
      chatId: 'c1',
      role: MessageRole.user,
      content: 'Ciao, come va?',
      timestamp: DateTime.utc(2026, 1, 1),
    );
    final markdownMessage = Message(
      id: 'm2',
      chatId: 'c1',
      role: MessageRole.ai,
      content: 'Ho segnato **50,00 €** di spesa.',
      timestamp: DateTime.utc(2026, 1, 1, 0, 1),
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
    fakeMessage.emit([plainMessage, markdownMessage]);
    await tester.pumpAndSettle();

    // Nessun marcatore: resta un `Text` semplice, `find.text(...)` esatto
    // continua a funzionare come per ogni altro test di questo file.
    expect(find.text('Ciao, come va?'), findsOneWidget);

    // Con `**`: il testo letterale coi marcatori non compare più come `Text`
    // semplice (i marcatori sono rimossi, il contenuto è diviso in frammenti
    // dentro un `Text.rich`) — il testo intero (marcatori rimossi) resta
    // comunque leggibile con `findRichText: true`, `RichText` concatena il
    // testo di tutti i suoi `TextSpan`.
    expect(find.text('Ho segnato **50,00 €** di spesa.'), findsNothing);
    final richTextFinder =
        find.text('Ho segnato 50,00 € di spesa.', findRichText: true);
    expect(richTextFinder, findsOneWidget);

    // Il frammento in grassetto è un TextSpan figlio con fontWeight w700, non
    // ereditato dallo stile di base della bolla.
    final richText = tester.widget<RichText>(richTextFinder);
    // `Text.rich(mySpan)` avvolge `mySpan` come unico figlio di un TextSpan
    // esterno (che porta lo stile ereditato da `DefaultTextStyle`): il
    // `TextSpan` passato da `_MessageText` è quindi un livello più in
    // profondità, non `richText.text` stesso.
    final ourSpan = (richText.text as TextSpan).children!.single as TextSpan;
    final boldChild = ourSpan.children!
        .whereType<TextSpan>()
        .firstWhere((span) => span.text == '50,00 €');
    expect(boldChild.style?.fontWeight, FontWeight.w700);
  });
}
