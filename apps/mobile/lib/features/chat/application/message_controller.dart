import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Messaggi di una Chat, in tempo reale.
final messagesProvider =
    StreamProvider.autoDispose.family<List<Message>, String>((ref, chatId) {
  return ref.watch(messageRepositoryProvider).watchMessages(chatId);
});

/// Eco locale del messaggio dell'utente appena inviato, mostrata subito senza
/// aspettare il giro di andata/ritorno di Realtime — senza, la bolla "sta
/// scrivendo" (mostrata a `isLoading == true`, prima ancora che il messaggio
/// reale sia stato scritto su `messages`) appariva come ultimo elemento della
/// lista sopra un messaggio dell'utente non ancora visibile: quando il
/// messaggio reale arrivava (spostando in basso la bolla "sta scrivendo"), lo
/// scatto risultante è quello segnalato dall'utente ad ogni invio, non solo
/// quando l'assistente risponde. Ripulita non appena arriva un aggiornamento
/// reale di `messagesProvider` (che, per come `sendMessage` inserisce prima
/// la riga utente e solo dopo chiama l'AI Engine, è sempre l'eco del
/// messaggio appena inviato) o al termine di `send()`, qualunque sia l'esito.
final optimisticMessageProvider =
    StateProvider.autoDispose.family<Message?, String>((ref, chatId) => null);

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
