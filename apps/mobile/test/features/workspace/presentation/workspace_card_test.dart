import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/workspace/presentation/widgets/workspace_card.dart';

import '../../../support/fake_workspace_repository.dart';

/// Verifica il requisito esplicito dell'utente ("vorrei che potessi
/// modificarlo o anche eliminarlo"): un Workspace libero espone Rinomina ed
/// Elimina, una sezione fissa (Fase 3, "Sezioni fisse") solo Rinomina — non è
/// strutturalmente eliminabile.
void main() {
  Future<void> pumpCard(WidgetTester tester, Workspace workspace) async {
    final fakeRepository = FakeWorkspaceRepository();
    addTearDown(fakeRepository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceRepositoryProvider.overrideWithValue(fakeRepository)
        ],
        child: MaterialApp(
          home: Scaffold(body: WorkspaceCard(workspace: workspace)),
        ),
      ),
    );
  }

  final freeWorkspace = Workspace(
    id: 'w1',
    ownerId: 'u1',
    name: 'Lavoro',
    icon: 'briefcase',
    status: WorkspaceStatus.active,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  final systemWorkspace = Workspace(
    id: 'w2',
    ownerId: 'u1',
    name: 'Bilancio',
    icon: 'folder',
    status: WorkspaceStatus.active,
    createdAt: DateTime.utc(2026, 1, 1),
    category: SystemWorkspaceCategory.bilancio,
  );

  testWidgets('Workspace libero: il menu mostra Rinomina ed Elimina',
      (tester) async {
    await pumpCard(tester, freeWorkspace);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Rinomina'), findsOneWidget);
    expect(find.text('Elimina'), findsOneWidget);
  });

  testWidgets('Sezione fissa: il menu mostra solo Rinomina', (tester) async {
    await pumpCard(tester, systemWorkspace);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Rinomina'), findsOneWidget);
    expect(find.text('Elimina'), findsNothing);
  });
}
