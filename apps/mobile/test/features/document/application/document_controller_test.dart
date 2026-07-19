import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/document/application/document_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_document_repository.dart';

void main() {
  const workspaceId = 'w1';
  final document = Document(
    id: 'd1',
    workspaceId: workspaceId,
    name: 'contratto.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 2048,
    storagePath: 'w1/1_contratto.pdf',
    hash: 'abc123',
    uploadedAt: DateTime.utc(2026, 1, 1),
  );

  late FakeDocumentRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeDocumentRepository();
    container = ProviderContainer(
      overrides: [documentRepositoryProvider.overrideWithValue(fakeRepository)],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
  });

  test('documentsProvider riflette lo stream del repository per workspace',
      () async {
    final subscription =
        container.listen(documentsProvider(workspaceId), (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emit([document]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(documentsProvider(workspaceId)).value, [document]);
  });

  test('upload con successo non ritorna errore', () async {
    fakeRepository.uploadResult = Result.ok(document);

    final failure =
        await container.read(documentFormControllerProvider.notifier).upload(
              workspaceId: workspaceId,
              fileName: 'contratto.pdf',
              mimeType: 'application/pdf',
              bytes: Uint8List.fromList([1, 2, 3]),
            );

    expect(failure, isNull);
    expect(fakeRepository.lastUploaded, document);
  });

  test('upload con nome vuoto ritorna un ValidationFailure', () async {
    fakeRepository.uploadResult =
        const Result.err(ValidationFailure('Il nome del file è obbligatorio.'));

    final failure =
        await container.read(documentFormControllerProvider.notifier).upload(
              workspaceId: workspaceId,
              fileName: '',
              mimeType: 'application/pdf',
              bytes: Uint8List.fromList([1, 2, 3]),
            );

    expect(failure, isA<ValidationFailure>());
  });

  test('delete delega al repository', () async {
    await container
        .read(documentFormControllerProvider.notifier)
        .delete(document.id);
    expect(fakeRepository.lastDeletedId, document.id);
  });

  test('open ritorna il Failure se il signed URL non è disponibile', () async {
    fakeRepository.downloadUrlResult = const Result.err(
        UnexpectedFailure('Non è stato possibile aprire il documento.'));

    final failure = await container
        .read(documentFormControllerProvider.notifier)
        .open(document);

    expect(failure, isA<UnexpectedFailure>());
  });
}
