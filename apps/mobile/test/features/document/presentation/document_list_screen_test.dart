import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/document/presentation/document_list_screen.dart';

import '../../../support/fake_document_repository.dart';

/// Conferma su swipe-to-delete (richiesta esplicita dell'utente: "conferma
/// su swipe-to-delete per elementi non banali") — un Documento cancellato
/// non è recuperabile con un tocco dopo lo swipe.
void main() {
  const workspaceId = 'w1';
  final document = Document(
    id: 'd1',
    workspaceId: workspaceId,
    name: 'scontrino.jpg',
    mimeType: 'image/jpeg',
    sizeBytes: 1024,
    storagePath: 'w1/d1',
    hash: 'abc',
    uploadedAt: DateTime.utc(2026, 1, 1),
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeDocumentRepository fakeRepository,
  ) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(fakeRepository)
        ],
        child: const MaterialApp(
          home: DocumentListScreen(workspaceId: workspaceId),
        ),
      ),
    );
  }

  testWidgets('scorrere un documento chiede conferma prima di cancellarlo',
      (tester) async {
    final fakeRepository = FakeDocumentRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([document]);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Eliminare questo documento?'), findsOneWidget);
    expect(fakeRepository.lastDeletedId, isNull);

    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(fakeRepository.lastDeletedId, 'd1');
  });
}
