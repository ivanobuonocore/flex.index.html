import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakePushSubscriptionRepository implements PushSubscriptionRepository {
  Result<Unit>? saveResult;
  Result<Unit>? sendTestResult;

  String? lastEndpoint;
  String? lastP256dh;
  String? lastAuthKey;
  int sendTestCallCount = 0;

  @override
  Future<Result<Unit>> saveSubscription({
    required String endpoint,
    required String p256dh,
    required String authKey,
  }) async {
    lastEndpoint = endpoint;
    lastP256dh = p256dh;
    lastAuthKey = authKey;
    return saveResult ??
        const Result.err(UnexpectedFailure('Nessun risultato configurato.'));
  }

  @override
  Future<Result<Unit>> sendTestNotification() async {
    sendTestCallCount += 1;
    return sendTestResult ??
        const Result.err(UnexpectedFailure('Nessun risultato configurato.'));
  }
}
