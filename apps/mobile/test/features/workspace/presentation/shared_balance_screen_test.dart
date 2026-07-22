import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/workspace/presentation/shared_balance_screen.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_workspace_repository.dart';
import '../../../support/fake_workspace_sharing_repository.dart';

/// Fase 3, "Bilancio condiviso" — richiesta esplicita dell'utente: due
/// Bilanci separati, uno personale e uno condiviso, raggiungibile creando un
/// nuovo Bilancio condiviso (con codice d'invito) o unendosi con un codice
/// ricevuto.
void main() {
  final me = User(
    id: 'u1',
    email: 'ada@pip.app',
    name: 'Ada',
    plan: UserPlan.free,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  late FakeAuthRepository fakeAuth;
  late FakeWorkspaceRepository fakeWorkspace;
  late FakeWorkspaceSharingRepository fakeSharing;

  Future<void> pumpScreen(WidgetTester tester) async {
    fakeAuth = FakeAuthRepository();
    fakeWorkspace = FakeWorkspaceRepository();
    fakeSharing = FakeWorkspaceSharingRepository();
    addTearDown(fakeAuth.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeSharing.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          workspaceSharingRepositoryProvider.overrideWithValue(fakeSharing),
        ],
        child: const MaterialApp(home: SharedBalanceScreen()),
      ),
    );

    fakeAuth.emit(me);
    fakeSharing.emitSharedBalances(const []);
    await tester.pumpAndSettle();
  }

  testWidgets('mostra lo stato vuoto quando non ci sono Bilanci condivisi',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Nessun Bilancio condiviso ancora'), findsOneWidget);
  });

  testWidgets('distingue i Bilanci posseduti da quelli condivisi con l\'utente',
      (tester) async {
    await pumpScreen(tester);

    final owned = Workspace(
      id: 'w1',
      ownerId: 'u1',
      name: 'Bilancio con Anna',
      icon: 'group',
      status: WorkspaceStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
      category: sharedBalanceCategory,
    );
    final memberOf = Workspace(
      id: 'w2',
      ownerId: 'u2',
      name: 'Bilancio di Anna',
      icon: 'group',
      status: WorkspaceStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
      category: sharedBalanceCategory,
    );

    fakeSharing.emitSharedBalances([owned, memberOf]);
    await tester.pumpAndSettle();

    expect(find.text('Bilancio con Anna'), findsOneWidget);
    expect(find.text('Bilancio di Anna'), findsOneWidget);
    expect(find.text('Creato da te'), findsOneWidget);
    expect(find.text('Condiviso con te'), findsOneWidget);
    // Solo il proprietario può gestire i membri.
    expect(find.byIcon(Icons.group_outlined), findsOneWidget);
  });

  testWidgets(
      'creare un Bilancio condiviso genera e mostra subito un codice d\'invito',
      (tester) async {
    await pumpScreen(tester);

    final created = Workspace(
      id: 'w1',
      ownerId: 'u1',
      name: 'Bilancio condiviso',
      icon: 'group',
      status: WorkspaceStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
      category: sharedBalanceCategory,
    );
    final invite = WorkspaceInvite(
      id: 'i1',
      workspaceId: 'w1',
      code: 'ABCD1234',
      createdBy: 'u1',
      createdAt: DateTime.utc(2026, 1, 1),
      expiresAt: DateTime.utc(2026, 1, 8),
    );
    fakeWorkspace.createResult = Result.ok(created);
    fakeSharing.createInviteResult = Result.ok(invite);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Crea'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crea e genera un codice'));
    await tester.pumpAndSettle();

    expect(find.text('ABCD1234'), findsOneWidget);
    expect(fakeSharing.lastInvitedWorkspaceId, 'w1');
  });

  testWidgets('unirsi con un codice valido chiude la schermata di redeem',
      (tester) async {
    await pumpScreen(tester);

    final joined = Workspace(
      id: 'w2',
      ownerId: 'u2',
      name: 'Bilancio di Anna',
      icon: 'group',
      status: WorkspaceStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
      category: sharedBalanceCategory,
    );
    fakeSharing.redeemInviteResult = Result.ok(joined);

    await tester.tap(find.text('Ho un codice d\'invito'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'abcd1234');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Unisciti'));
    await tester.pumpAndSettle();

    expect(fakeSharing.lastRedeemedCode, 'abcd1234');
    // Il bottom sheet si è chiuso: il campo codice non è più visibile.
    expect(find.text('Unisciti a un Bilancio condiviso'), findsNothing);
  });

  testWidgets('un codice non valido mostra l\'errore e non chiude il foglio',
      (tester) async {
    await pumpScreen(tester);

    fakeSharing.redeemInviteResult =
        const Result.err(ValidationFailure('Codice d\'invito non valido.'));

    await tester.tap(find.text('Ho un codice d\'invito'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'XXXXXXXX');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Unisciti'));
    await tester.pumpAndSettle();

    expect(find.text('Codice d\'invito non valido.'), findsOneWidget);
    expect(find.text('Unisciti a un Bilancio condiviso'), findsOneWidget);
  });

  testWidgets(
      'il proprietario può vedere e rimuovere un membro dal Bilancio condiviso',
      (tester) async {
    await pumpScreen(tester);

    final owned = Workspace(
      id: 'w1',
      ownerId: 'u1',
      name: 'Bilancio con Anna',
      icon: 'group',
      status: WorkspaceStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
      category: sharedBalanceCategory,
    );
    fakeSharing.emitSharedBalances([owned]);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.group_outlined));
    // Non `pumpAndSettle`: `workspaceMembersProvider` è ancora in `loading`
    // (nessun dato emesso ancora) e lo spinner d'attesa anima all'infinito.
    await tester.pump();
    await tester.pump();

    final member = WorkspaceMember(
      id: 'm1',
      workspaceId: 'w1',
      userId: 'u2',
      joinedAt: DateTime.utc(2026, 1, 2),
    );
    fakeSharing.emitMembers('w1', [member]);
    await tester.pumpAndSettle();

    expect(find.text('u2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_remove_outlined));
    await tester.pumpAndSettle();

    expect(fakeSharing.lastRemovedMember, (workspaceId: 'w1', userId: 'u2'));
  });
}
