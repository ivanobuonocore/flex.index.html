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

  /// Se impostato, `sendMessage` lancia questo errore invece di ritornare un
  /// `Result` — simula un fallimento che scappa dal `try/catch` interno del
  /// repository reale (es. un rifiuto della Promise JS non intercettato
  /// sotto l'interop web di supabase_flutter), usato per verificare che
  /// [MessageFormController.send] non lasci `isLoading` bloccato per sempre.
  Object? throwOnSend;

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
    if (throwOnSend != null) throw throwOnSend!;
    return sendResult ?? const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
