import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/shared/widgets/document_thumbnail.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../support/fake_document_repository.dart';

/// Lightbox sulle foto allegate (integrazione richiesta esplicitamente):
/// toccare una miniatura già caricata apre un visualizzatore a schermo
/// intero con zoom, sia in Chat sia nella lista Documenti (stesso widget
/// condiviso `DocumentThumbnail`, un solo punto da testare).
void main() {
  final document = Document(
    id: 'd1',
    workspaceId: 'w1',
    name: 'foto.jpg',
    mimeType: 'image/jpeg',
    sizeBytes: 1024,
    storagePath: 'w1/foto.jpg',
    hash: 'abc',
    uploadedAt: DateTime.utc(2026, 1, 1),
  );

  testWidgets(
      'toccare la miniatura caricata apre il visualizzatore a schermo intero con zoom',
      (tester) async {
    final fakeRepository = FakeDocumentRepository(
      getDocumentResult: Result.ok(document),
      downloadUrlResult: const Result.ok('https://example.invalid/foto.jpg'),
    );
    addTearDown(fakeRepository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(fakeRepository)
        ],
        child: const MaterialApp(
          home: Scaffold(body: DocumentThumbnail(documentId: 'd1')),
        ),
      ),
    );
    // Risolve il FutureProvider. Nessuna vera rete in `flutter test`:
    // `Image.network` fallisce sempre con uno status 400 (limite noto del
    // test binding, non di questo widget — nessun `mockNetworkImagesFor` in
    // questo progetto, stessa scelta già presa altrove). L'errore resta
    // gestito visivamente dal proprio `errorBuilder`, ma Flutter lo segnala
    // comunque come eccezione "non gestita" al framework di test: va
    // consumato esplicitamente con `takeException()`, altrimenti il test
    // fallirebbe anche se il comportamento verificato è corretto.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.takeException();

    expect(find.byType(InteractiveViewer), findsNothing);

    await tester.tap(find.byType(GestureDetector));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('una miniatura ancora in caricamento non apre nulla al tocco',
      (tester) async {
    final fakeRepository = FakeDocumentRepository();
    addTearDown(fakeRepository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(fakeRepository)
        ],
        child: const MaterialApp(
          home: Scaffold(body: DocumentThumbnail(documentId: 'd1')),
        ),
      ),
    );

    // Nessun `pump()` successivo: nel primissimo fotogramma il
    // `FutureProvider` è ancora in stato "loading" (il repository fittizio
    // non ha nemmeno completato la propria `Future`) — solo il ramo `data`
    // avvolge l'immagine con un `GestureDetector`, quindi qui non c'è
    // ancora nulla da toccare.
    expect(find.byType(GestureDetector), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
