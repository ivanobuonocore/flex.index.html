import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/workspace/presentation/workspace_detail_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_workspace_repository.dart';
import '../../../support/fake_workspace_sharing_repository.dart';

/// FAB "azione rapida" sulla Home del Workspace (richiesta esplicita
/// dell'utente): un tocco apre un menu con le quattro sheet di creazione già
/// esistenti (Nota/Attività/Transazione/Promemoria), nascosto per un membro
/// con ruolo `viewer` — stesso principio già applicato altrove.
void main() {
  const workspaceId = 'w1';
  const userId = 'u1';
  final workspace = Workspace(
    id: workspaceId,
    ownerId: 'owner',
    name: 'Lavoro',
    icon: 'briefcase',
    status: WorkspaceStatus.active,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  Future<void> pumpScreen(WidgetTester tester) async {
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeSharing = FakeWorkspaceSharingRepository();
    final fakeAuth = FakeAuthRepository();
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeSharing.dispose);
    addTearDown(fakeAuth.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          workspaceSharingRepositoryProvider.overrideWithValue(fakeSharing),
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
        child: const MaterialApp(
          home: WorkspaceDetailScreen(workspaceId: workspaceId),
        ),
      ),
    );
    fakeWorkspace.emit([workspace]);
    fakeSharing.emitMembers(workspaceId, const []);
    await tester.pump();
  }

  // "Attività"/"Promemoria" compaiono anche come titolo di una sezione della
  // Home del Workspace, dietro la sheet: il finder va ristretto alla voce di
  // menu (un ListTile dentro la BottomSheet) per restare univoco.
  Finder menuItem(String label) => find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(ListTile, label),
      );

  testWidgets(
      'un editor (o il proprietario, nessuna riga membro) vede il FAB con le 4 voci',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(menuItem('Nota'), findsOneWidget);
    expect(menuItem('Attività'), findsOneWidget);
    expect(menuItem('Transazione'), findsOneWidget);
    expect(menuItem('Promemoria'), findsOneWidget);
  });

  testWidgets('la voce Nota apre la sheet di creazione nota', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(menuItem('Nota'));
    await tester.pumpAndSettle();

    expect(find.text('Nuova nota'), findsOneWidget);
  });

  testWidgets('la voce Attività apre la sheet di creazione task',
      (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(menuItem('Attività'));
    await tester.pumpAndSettle();

    expect(find.text('Nuova task'), findsOneWidget);
  });

  testWidgets('la voce Transazione apre la sheet di creazione transazione',
      (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(menuItem('Transazione'));
    await tester.pumpAndSettle();

    expect(find.text('Nuova transazione'), findsOneWidget);
  });

  testWidgets('la voce Promemoria apre la sheet di creazione promemoria',
      (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(menuItem('Promemoria'));
    await tester.pumpAndSettle();

    expect(find.text('Nuovo promemoria'), findsOneWidget);
  });

  testWidgets('un membro con ruolo viewer non vede il FAB', (tester) async {
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeSharing = FakeWorkspaceSharingRepository();
    final fakeAuth = FakeAuthRepository();
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeSharing.dispose);
    addTearDown(fakeAuth.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          workspaceSharingRepositoryProvider.overrideWithValue(fakeSharing),
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
        child: const MaterialApp(
          home: WorkspaceDetailScreen(workspaceId: workspaceId),
        ),
      ),
    );
    fakeWorkspace.emit([workspace]);
    fakeAuth.emit(User(
      id: userId,
      email: 'viewer@test.com',
      name: 'Viewer',
      plan: UserPlan.free,
      createdAt: DateTime.now(),
    ));
    fakeSharing.emitMembers(workspaceId, [
      WorkspaceMember(
        id: 'm1',
        workspaceId: workspaceId,
        userId: userId,
        joinedAt: DateTime.now(),
        role: WorkspaceRole.viewer,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
