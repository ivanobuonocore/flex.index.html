import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/document/application/document_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_document_repository.dart';
import '../../../support/fake_transaction_repository.dart';

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

  test('upload con successo ritorna il Document creato', () async {
    fakeRepository.uploadResult = Result.ok(document);

    final result =
        await container.read(documentFormControllerProvider.notifier).upload(
              workspaceId: workspaceId,
              fileName: 'contratto.pdf',
              mimeType: 'application/pdf',
              bytes: Uint8List.fromList([1, 2, 3]),
            );

    expect(result.isOk, isTrue);
    expect((result as Ok<Document>).value, document);
    expect(fakeRepository.lastUploaded, document);
  });

  test('upload con nome vuoto ritorna un ValidationFailure', () async {
    fakeRepository.uploadResult =
        const Result.err(ValidationFailure('Il nome del file è obbligatorio.'));

    final result =
        await container.read(documentFormControllerProvider.notifier).upload(
              workspaceId: workspaceId,
              fileName: '',
              mimeType: 'application/pdf',
              bytes: Uint8List.fromList([1, 2, 3]),
            );

    expect(result.isErr, isTrue);
    expect((result as Err<Document>).failure, isA<ValidationFailure>());
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

  group('linkedDocumentIdsProvider', () {
    late FakeTransactionRepository fakeTransactionRepository;
    late ProviderContainer kgContainer;

    setUp(() {
      fakeTransactionRepository = FakeTransactionRepository();
      kgContainer = ProviderContainer(
        overrides: [
          transactionRepositoryProvider
              .overrideWithValue(fakeTransactionRepository),
        ],
      );
      addTearDown(kgContainer.dispose);
      addTearDown(fakeTransactionRepository.dispose);
    });

    Transaction transactionWithDocument(String? documentId) => Transaction(
          id: 'tx-${documentId ?? 'none'}',
          workspaceId: workspaceId,
          type: TransactionType.expense,
          description: 'Spesa',
          amountCents: 1000,
          occurredAt: DateTime.utc(2026, 1, 1),
          status: TransactionStatus.confirmed,
          createdByAi: false,
          createdAt: DateTime.utc(2026, 1, 1),
          documentId: documentId,
        );

    test(
        'contiene gli id dei Documenti referenziati da almeno una '
        'Transazione', () async {
      final subscription = kgContainer.listen(
          linkedDocumentIdsProvider(workspaceId), (_, __) {});
      addTearDown(subscription.close);

      fakeTransactionRepository.emit([
        transactionWithDocument('d1'),
        transactionWithDocument(null),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(
        kgContainer.read(linkedDocumentIdsProvider(workspaceId)),
        {'d1'},
      );
    });

    test('insieme vuoto se nessuna Transazione ha un documento allegato',
        () async {
      final subscription = kgContainer.listen(
          linkedDocumentIdsProvider(workspaceId), (_, __) {});
      addTearDown(subscription.close);

      fakeTransactionRepository.emit([transactionWithDocument(null)]);
      await Future<void>.delayed(Duration.zero);

      expect(kgContainer.read(linkedDocumentIdsProvider(workspaceId)), isEmpty);
    });
  });
}
