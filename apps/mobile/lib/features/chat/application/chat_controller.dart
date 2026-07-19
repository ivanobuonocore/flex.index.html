import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Chat dell'utente, in tempo reale. `workspaceId` null = tutte le Chat (tab
/// globale); valorizzato = solo quelle di un Workspace (Home del Workspace).
final chatsProvider = StreamProvider.autoDispose.family<List<Chat>, String?>((ref, workspaceId) {
  return ref.watch(chatRepositoryProvider).watchChats(workspaceId);
});

final chatFormControllerProvider =
    AsyncNotifierProvider.autoDispose<ChatFormController, void>(ChatFormController.new);

class ChatFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Ritorna la Chat creata (non solo l'eventuale errore, a differenza delle
  /// altre feature): la UI naviga subito al dettaglio, non basta sapere che
  /// l'operazione è riuscita.
  Future<Result<Chat>> create({required String? workspaceId, required String title}) async {
    state = const AsyncLoading();
    final result = await ref
        .read(chatRepositoryProvider)
        .createChat(workspaceId: workspaceId, title: title);
    state = const AsyncData(null);
    return result;
  }

  Future<Failure?> archive(String chatId) async {
    state = const AsyncLoading();
    final result = await ref.read(chatRepositoryProvider).archiveChat(chatId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}
