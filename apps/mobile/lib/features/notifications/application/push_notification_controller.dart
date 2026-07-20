import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';
import '../data/push_notification_service.dart';
import '../data/push_notification_service_provider.dart';

/// Interop col browser (Web Push, Service Worker) — mai chiamato
/// direttamente dalla UI, sempre tramite [PushNotificationController]
/// (Dependency Inversion, stesso principio dei repository di dominio).
final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  return createPushNotificationService();
});

/// Stato corrente (non supportato / da attivare / attivo), senza effetti
/// collaterali — usato dalla card "Notifiche" in Profilo per decidere quale
/// pulsante mostrare.
final pushSupportStatusProvider =
    FutureProvider.autoDispose<PushSupportStatus>((ref) {
  return ref.watch(pushNotificationServiceProvider).checkStatus();
});

final pushNotificationControllerProvider =
    AsyncNotifierProvider.autoDispose<PushNotificationController, void>(
  PushNotificationController.new,
);

class PushNotificationController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Chiede il permesso, si iscrive al push service del browser e salva le
  /// credenziali su Supabase. Un `null` da [PushNotificationService.subscribe]
  /// (permesso negato, piattaforma non supportata) è un esito normale, non
  /// un errore tecnico: il messaggio spiega cosa fare, non che qualcosa si è
  /// rotto.
  Future<Failure?> subscribe(String vapidPublicKey) async {
    state = const AsyncLoading();
    final keys = await ref
        .read(pushNotificationServiceProvider)
        .subscribe(vapidPublicKey);
    if (keys == null) {
      state = const AsyncData(null);
      return const UnexpectedFailure(
        'Non è stato possibile attivare le notifiche su questo dispositivo. '
        'Verifica di aver consentito le notifiche; su iPhone funzionano solo '
        'se hai aggiunto il sito alla schermata Home (icona Condividi → '
        'Aggiungi a Home, richiede iOS 16.4 o successivo).',
      );
    }

    final result =
        await ref.read(pushSubscriptionRepositoryProvider).saveSubscription(
              endpoint: keys.endpoint,
              p256dh: keys.p256dh,
              authKey: keys.authKey,
            );
    state = const AsyncData(null);
    final failure = result.fold((_) => null, (failure) => failure);
    if (failure == null) {
      ref.invalidate(pushSupportStatusProvider);
    }
    return failure;
  }

  Future<Failure?> sendTestNotification() async {
    state = const AsyncLoading();
    final result = await ref
        .read(pushSubscriptionRepositoryProvider)
        .sendTestNotification();
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}
