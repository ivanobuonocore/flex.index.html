import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/transaction/presentation/transaction_report_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_budget_repository.dart';
import '../../../support/fake_transaction_repository.dart';
import '../../../support/fake_workspace_sharing_repository.dart';

/// Permessi granulari sui Workspace condivisi (integrazione richiesta
/// esplicitamente: "viewer" in sola lettura, "editor" come oggi). Un membro
/// con ruolo `viewer` in questo Workspace non deve vedere alcuna azione di
/// scrittura (FAB, conferma/scarta, apertura della sheet di modifica).
void main() {
  const workspaceId = 'w1';
  const userId = 'u1';
  final transaction = Transaction(
    id: 't1',
    workspaceId: workspaceId,
    type: TransactionType.expense,
    description: 'Spesa',
    amountCents: 1000,
    occurredAt: DateTime.now(),
    status: TransactionStatus.confirmed,
    createdAt: DateTime.now(),
  );
  final pendingTransaction = Transaction(
    id: 't2',
    workspaceId: workspaceId,
    type: TransactionType.expense,
    description: 'Spesa suggerita',
    amountCents: 500,
    occurredAt: DateTime.now(),
    status: TransactionStatus.pending,
    createdAt: DateTime.now(),
    createdByAi: true,
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required FakeTransactionRepository fakeTransaction,
    required FakeWorkspaceSharingRepository fakeSharing,
    required FakeAuthRepository fakeAuth,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceSharingRepositoryProvider.overrideWithValue(fakeSharing),
          authRepositoryProvider.overrideWithValue(fakeAuth),
          budgetRepositoryProvider.overrideWithValue(FakeBudgetRepository()),
        ],
        child: const MaterialApp(
          home: TransactionReportScreen(workspaceId: workspaceId),
        ),
      ),
    );
  }

  testWidgets(
      'un editor (o il proprietario, nessuna riga membro) vede il pulsante Aggiungi',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeSharing = FakeWorkspaceSharingRepository();
    final fakeAuth = FakeAuthRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeSharing.dispose);
    addTearDown(fakeAuth.dispose);

    await pumpScreen(tester,
        fakeTransaction: fakeTransaction,
        fakeSharing: fakeSharing,
        fakeAuth: fakeAuth);
    fakeTransaction.emit([transaction]);
    fakeSharing.emitMembers(workspaceId, const []);
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets(
      'un membro con ruolo viewer non vede il pulsante Aggiungi né può modificare',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeSharing = FakeWorkspaceSharingRepository();
    final fakeAuth = FakeAuthRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeSharing.dispose);
    addTearDown(fakeAuth.dispose);

    await pumpScreen(tester,
        fakeTransaction: fakeTransaction,
        fakeSharing: fakeSharing,
        fakeAuth: fakeAuth);
    fakeTransaction.emit([transaction, pendingTransaction]);
    fakeSharing.emitMembers(workspaceId, [
      WorkspaceMember(
        id: 'm1',
        workspaceId: workspaceId,
        userId: userId,
        joinedAt: DateTime.now(),
        role: WorkspaceRole.viewer,
      ),
    ]);
    fakeAuth.emit(User(
      id: userId,
      email: 'viewer@test.com',
      name: 'Viewer',
      plan: UserPlan.free,
      createdAt: DateTime.now(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    // Il tap non deve aprire la sheet di modifica.
    await tester.tap(find.text('Spesa'));
    await tester.pumpAndSettle();
    expect(find.text('Modifica transazione'), findsNothing);
    // Nessuna azione di conferma/scarta sulla transazione pending.
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
