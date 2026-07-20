import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({this.createResult});

  final _controller = StreamController<List<Chat>>.broadcast();
  Result<Chat>? createResult;
  Chat? lastCreated;
  String? lastArchivedId;
  String? lastRequestedWorkspaceId;

  void emit(List<Chat> chats) => _controller.add(chats);

  @override
  Stream<List<Chat>> watchChats(String? workspaceId) {
    lastRequestedWorkspaceId = workspaceId;
    return _controller.stream;
  }

  @override
  Future<Result<Chat>> createChat({
    required String? workspaceId,
    required String title,
  }) async {
    final result = createResult ??
        const Result<Chat>.err(
            ValidationFailure('Nessun risultato configurato.'));
    if (result.isOk) {
      lastCreated = (result as Ok<Chat>).value;
    }
    return result;
  }

  @override
  Future<Result<Unit>> archiveChat(String chatId) async {
    lastArchivedId = chatId;
    return const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
