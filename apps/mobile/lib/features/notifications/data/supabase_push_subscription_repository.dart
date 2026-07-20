import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [PushSubscriptionRepository]. `saveSubscription` fa un
/// upsert su `endpoint` (colonna `unique`): ri-attivare le notifiche sullo
/// stesso dispositivo aggiorna la riga esistente invece di duplicarla.
class SupabasePushSubscriptionRepository implements PushSubscriptionRepository {
  SupabasePushSubscriptionRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _table = 'push_subscriptions';
  static const _sendTestPushFunction = 'send-test-push';

  @override
  Future<Result<Unit>> saveSubscription({
    required String endpoint,
    required String p256dh,
    required String authKey,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const Result.err(
          AuthFailure('Devi accedere per attivare le notifiche.'));
    }

    try {
      await _client.from(_table).upsert(
        {
          'user_id': userId,
          'endpoint': endpoint,
          'p256dh': p256dh,
          'auth_key': authKey,
        },
        onConflict: 'endpoint',
      );
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile attivare le notifiche.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Unit>> sendTestNotification() async {
    try {
      final response = await _client.functions.invoke(_sendTestPushFunction);
      if (response.status != 200) {
        return const Result.err(
          UnexpectedFailure(
              'Non è stato possibile inviare la notifica di prova.'),
        );
      }
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile inviare la notifica di prova.',
            cause: e),
      );
    }
  }
}
