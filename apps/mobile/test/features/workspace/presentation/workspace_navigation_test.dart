import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/main.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_chat_repository.dart';
import '../../../support/fake_document_repository.dart';
import '../../../support/fake_note_repository.dart';
import '../../../support/fake_task_repository.dart';
import '../../../support/fake_workspace_repository.dart';

void main() {
  testWidgets('toccare una WorkspaceCard apre la Home del Workspace',
      (tester) async {
    final fakeAuth = FakeAuthRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeNote = FakeNoteRepository();
    final fakeTask = FakeTaskRepository();
    final fakeDocument = FakeDocumentRepository();
    final fakeChat = FakeChatRepository();
    addTearDown(fakeAuth.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeNote.dispose);
    addTearDown(fakeTask.dispose);
    addTearDown(fakeDocument.dispose);
    addTearDown(fakeChat.dispose);

    final user = User(
      id: 'u1',
      email: 'ada@pip.app',
      name: 'Ada',
      plan: UserPlan.free,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final workspace = Workspace(
      id: 'w1',
      ownerId: user.id,
      name: 'Lavoro',
      icon: 'briefcase',
      status: WorkspaceStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          noteRepositoryProvider.overrideWithValue(fakeNote),
          taskRepositoryProvider.overrideWithValue(fakeTask),
          documentRepositoryProvider.overrideWithValue(fakeDocument),
          chatRepositoryProvider.overrideWithValue(fakeChat),
        ],
        child: const PipApp(),
      ),
    );

    fakeAuth.emit(user);
    await tester.pump(); // elabora il redirect verso /today
    // TodayScreen osserva già workspacesProvider: emettere qui evita uno
    // spinner infinito che farebbe scadere pumpAndSettle.
    fakeWorkspace.emit([workspace]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workspace'));
    await tester.pumpAndSettle();

    expect(find.text('Lavoro'), findsOneWidget);

    await tester.tap(find.text('Lavoro'));
    await tester
        .pump(); // costruisce WorkspaceDetailScreen, sottoscrive Note/Task/Documenti
    fakeNote.emit(const []);
    fakeTask.emit(const []);
    fakeDocument.emit(const []);
    fakeChat.emit(const []);
    await tester.pumpAndSettle();

    expect(find.text('Note'), findsOneWidget);
    expect(find.text('Attività'), findsOneWidget);
    expect(find.text('Documenti'), findsOneWidget);

    // La sezione Chat allunga la pagina oltre il viewport di test: la sliver
    // list costruisce "Prossimamente" solo una volta scrollato in vista.
    await tester.scrollUntilVisible(
      find.text('Prossimamente'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Prossimamente'), findsOneWidget);
  });
}
