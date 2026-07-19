import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/chat/application/message_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_message_repository.dart';

void main() {
  const chatId = 'c1';
  const workspaceId = 'w1';
  final message = Message(
    id: 'm1',
    chatId: chatId,
    role: MessageRole.user,
    content: 'Ciao',
    timestamp: DateTime.utc(2026, 1, 1),
  );

  late FakeMessageRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeMessageRepository();
    container = ProviderContainer(
      overrides: [messageRepositoryProvider.overrideWithValue(fakeRepository)],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
  });

  test('messagesProvider riflette lo stream del repository per chat',
      () async {
    final subscription = container.listen(messagesProvider(chatId), (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emit([message]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(messagesProvider(chatId)).value, [message]);
  });

  test('send con successo non ritorna errore e inoltra i parametri',
      () async {
    final failure = await container
        .read(messageFormControllerProvider.notifier)
        .send(chatId: chatId, workspaceId: workspaceId, content: 'Ciao');

    expect(failure, isNull);
    expect(fakeRepository.lastChatId, chatId);
    expect(fakeRepository.lastWorkspaceId, workspaceId);
    expect(fakeRepository.lastContent, 'Ciao');
  });

  test('send propaga il Failure del repository in caso di errore', () async {
    fakeRepository.sendResult = const Result.err(
      UnexpectedFailure('L\'assistente non è riuscito a rispondere. Riprova.'),
    );

    final failure = await container
        .read(messageFormControllerProvider.notifier)
        .send(chatId: chatId, workspaceId: workspaceId, content: 'Ciao');

    expect(failure, isA<UnexpectedFailure>());
  });

  test('send inoltra attachmentIds al repository', () async {
    await container.read(messageFormControllerProvider.notifier).send(
          chatId: chatId,
          workspaceId: workspaceId,
          content: 'Guarda questa foto',
          attachmentIds: const ['d1'],
        );

    expect(fakeRepository.lastAttachmentIds, ['d1']);
  });

  test('send senza attachmentIds inoltra una lista vuota', () async {
    await container
        .read(messageFormControllerProvider.notifier)
        .send(chatId: chatId, workspaceId: workspaceId, content: 'Ciao');

    expect(fakeRepository.lastAttachmentIds, isEmpty);
  });
}
