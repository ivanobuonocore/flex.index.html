import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/chat/application/chat_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_chat_repository.dart';

void main() {
  const workspaceId = 'w1';
  final chat = Chat(
    id: 'c1',
    ownerId: 'u1',
    workspaceId: workspaceId,
    title: 'Prima chat',
    aiModel: 'claude-sonnet-5',
    status: ChatStatus.active,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  late FakeChatRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeChatRepository();
    container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(fakeRepository)],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
  });

  test('chatsProvider riflette lo stream del repository per workspace',
      () async {
    final subscription =
        container.listen(chatsProvider(workspaceId), (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emit([chat]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(chatsProvider(workspaceId)).value, [chat]);
    expect(fakeRepository.lastRequestedWorkspaceId, workspaceId);
  });

  test('chatsProvider(null) chiede tutte le chat dell\'utente', () async {
    final subscription = container.listen(chatsProvider(null), (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emit([chat]);
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepository.lastRequestedWorkspaceId, isNull);
  });

  test('create con successo ritorna la Chat creata', () async {
    fakeRepository.createResult = Result.ok(chat);

    final result = await container
        .read(chatFormControllerProvider.notifier)
        .create(workspaceId: workspaceId, title: 'Prima chat');

    expect(result.isOk, isTrue);
    expect((result as Ok<Chat>).value, chat);
    expect(fakeRepository.lastCreated, chat);
  });

  test('create con titolo vuoto ritorna un ValidationFailure', () async {
    fakeRepository.createResult =
        const Result.err(ValidationFailure('Il titolo è obbligatorio.'));

    final result = await container
        .read(chatFormControllerProvider.notifier)
        .create(workspaceId: workspaceId, title: '');

    expect(result.isErr, isTrue);
    expect((result as Err<Chat>).failure, isA<ValidationFailure>());
  });

  test('archive delega al repository', () async {
    final failure = await container
        .read(chatFormControllerProvider.notifier)
        .archive(chat.id);

    expect(failure, isNull);
    expect(fakeRepository.lastArchivedId, chat.id);
  });

  test('singleChatProvider riusa la Chat più recente se esiste già', () async {
    final subscription = container.listen(chatsProvider(null), (_, __) {});
    addTearDown(subscription.close);
    fakeRepository.emit([chat]);
    await Future<void>.delayed(Duration.zero);

    final result = await container.read(singleChatProvider.future);

    expect(result, chat);
    expect(fakeRepository.lastCreated, isNull); // non ne crea una seconda
  });

  test('singleChatProvider ne crea una privata solo se non esiste nessuna',
      () async {
    fakeRepository.createResult = Result.ok(chat);
    final subscription = container.listen(chatsProvider(null), (_, __) {});
    addTearDown(subscription.close);
    fakeRepository.emit(const []);
    await Future<void>.delayed(Duration.zero);

    final result = await container.read(singleChatProvider.future);

    expect(result, chat);
    expect(fakeRepository.lastCreated, chat);
  });
}
