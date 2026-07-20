import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Messaggi di una Chat, in tempo reale.
final messagesProvider =
    StreamProvider.autoDispose.family<List<Message>, String>((ref, chatId) {
  return ref.watch(messageRepositoryProvider).watchMessages(chatId);
});

final messageFormControllerProvider =
    AsyncNotifierProvider.autoDispose<MessageFormController, void>(
        MessageFormController.new);

class MessageFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// `isLoading` copre l'intero turno (invio + attesa della risposta AI): la
  /// UI lo usa per mostrare "l'assistente sta scrivendo" invece di uno stato
  /// separato dedicato.
  Future<Failure?> send({
    required String chatId,
    required String? workspaceId,
    required String content,
    List<String> attachmentIds = const [],
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(messageRepositoryProvider).sendMessage(
          chatId: chatId,
          workspaceId: workspaceId,
          content: content,
          attachmentIds: attachmentIds,
        );
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}
