import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
