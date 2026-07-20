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
  List<String>? lastAttachmentIds;

  /// Se impostato, `sendMessage` resta in sospeso finché questo Completer
  /// non viene risolto — permette ai test di osservare lo stato
  /// intermedio "in corso" (es. la bolla "sta scrivendo…").
  Completer<void>? pendingSend;

  void emit(List<Message> messages) => _controller.add(messages);

  @override
  Stream<List<Message>> watchMessages(String chatId) => _controller.stream;

  @override
  Future<Result<Unit>> sendMessage({
    required String chatId,
    required String? workspaceId,
    required String content,
    List<String> attachmentIds = const [],
  }) async {
    lastChatId = chatId;
    lastWorkspaceId = workspaceId;
    lastContent = content;
    lastAttachmentIds = attachmentIds;
    if (pendingSend != null) await pendingSend!.future;
    return sendResult ?? const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
