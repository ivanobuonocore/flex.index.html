import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeMessageRepository implements MessageRepository {
  FakeMessageRepository({this.sendResult});

  final _controller = StreamController<List<Message>>.broadcast();
  Result<Unit>? sendResult;
  String? lastChatId;
  String? lastWorkspaceId;
  String? lastContent;

  void emit(List<Message> messages) => _controller.add(messages);

  @override
  Stream<List<Message>> watchMessages(String chatId) => _controller.stream;

  @override
  Future<Result<Unit>> sendMessage({
    required String chatId,
    required String? workspaceId,
    required String content,
  }) async {
    lastChatId = chatId;
    lastWorkspaceId = workspaceId;
    lastContent = content;
    return sendResult ?? const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
