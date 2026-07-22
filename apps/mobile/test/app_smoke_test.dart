import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/main.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_workspace_repository.dart';

void main() {
  testWidgets('utente non autenticato viene indirizzato al login',
      (tester) async {
    final fakeAuth = FakeAuthRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    addTearDown(fakeAuth.dispose);
    addTearDown(fakeWorkspace.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
        ],
        child: const PipApp(),
      ),
    );

    fakeAuth.emit(null);
    await tester.pumpAndSettle();

    expect(find.text('Bentornato'), findsOneWidget);
  });

  testWidgets(
      'utente autenticato senza onboarding completato viene indirizzato lì '
      'invece che alla Chat', (tester) async {
    final fakeAuth = FakeAuthRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    addTearDown(fakeAuth.dispose);
    addTearDown(fakeWorkspace.dispose);

    final user = User(
      id: 'u1',
      email: 'ada@pip.app',
      name: 'Ada',
      plan: UserPlan.free,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
        ],
        child: const PipApp(),
      ),
    );

    fakeAuth.emit(user);
    await tester.pumpAndSettle();

    // Non la Home Chat: la prima cosa che vede è l'onboarding.
    expect(find.text('Tutto parte dalla Chat'), findsOneWidget);
    expect(find.text('Salta'), findsOneWidget);
  });

  testWidgets(
      'utente autenticato con onboarding già completato va direttamente '
      'alla Chat', (tester) async {
    final fakeAuth = FakeAuthRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    addTearDown(fakeAuth.dispose);
    addTearDown(fakeWorkspace.dispose);

    final user = User(
      id: 'u1',
      email: 'ada@pip.app',
      name: 'Ada',
      plan: UserPlan.free,
      createdAt: DateTime.utc(2026, 1, 1),
      onboardingCompleted: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
        ],
        child: const PipApp(),
      ),
    );

    fakeAuth.emit(user);
    fakeWorkspace.emit(const []);
    await tester.pumpAndSettle();

    expect(find.text('Tutto parte dalla Chat'), findsNothing);
  });
}
