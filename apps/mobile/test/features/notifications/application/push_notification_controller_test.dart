import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/notifications/application/push_notification_controller.dart';
import 'package:pip_mobile/features/notifications/data/push_notification_service.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_push_notification_service.dart';
import '../../../support/fake_push_subscription_repository.dart';

void main() {
  late FakePushNotificationService fakeService;
  late FakePushSubscriptionRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeService = FakePushNotificationService();
    fakeRepository = FakePushSubscriptionRepository();
    container = ProviderContainer(
      overrides: [
        pushNotificationServiceProvider.overrideWithValue(fakeService),
        pushSubscriptionRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('pushSupportStatusProvider riflette lo stato del service', () async {
    fakeService.statusResult = PushSupportStatus.subscribed;

    final status = await container.read(pushSupportStatusProvider.future);

    expect(status, PushSupportStatus.subscribed);
  });

  test('subscribe con permesso concesso salva le credenziali e non ritorna errore',
      () async {
    fakeService.subscribeResult = const PushSubscriptionKeys(
      endpoint: 'https://push.example/abc',
      p256dh: 'p256dh-value',
      authKey: 'auth-value',
    );
    fakeRepository.saveResult = const Result.ok(unit);

    final failure = await container
        .read(pushNotificationControllerProvider.notifier)
        .subscribe('vapid-public-key');

    expect(failure, isNull);
    expect(fakeService.lastVapidPublicKey, 'vapid-public-key');
    expect(fakeRepository.lastEndpoint, 'https://push.example/abc');
    expect(fakeRepository.lastP256dh, 'p256dh-value');
    expect(fakeRepository.lastAuthKey, 'auth-value');
  });

  test('subscribe con permesso negato (service ritorna null) ritorna un Failure',
      () async {
    fakeService.subscribeResult = null;

    final failure = await container
        .read(pushNotificationControllerProvider.notifier)
        .subscribe('vapid-public-key');

    expect(failure, isA<UnexpectedFailure>());
    expect(fakeRepository.lastEndpoint, isNull);
  });

  test('subscribe propaga il Failure del repository se il salvataggio fallisce',
      () async {
    fakeService.subscribeResult = const PushSubscriptionKeys(
      endpoint: 'https://push.example/abc',
      p256dh: 'p256dh-value',
      authKey: 'auth-value',
    );
    fakeRepository.saveResult =
        const Result.err(UnexpectedFailure('Salvataggio fallito.'));

    final failure = await container
        .read(pushNotificationControllerProvider.notifier)
        .subscribe('vapid-public-key');

    expect(failure, isA<UnexpectedFailure>());
  });

  test('sendTestNotification delega al repository', () async {
    fakeRepository.sendTestResult = const Result.ok(unit);

    final failure = await container
        .read(pushNotificationControllerProvider.notifier)
        .sendTestNotification();

    expect(failure, isNull);
    expect(fakeRepository.sendTestCallCount, 1);
  });

  test('sendTestNotification propaga il Failure del repository', () async {
    fakeRepository.sendTestResult =
        const Result.err(UnexpectedFailure('Invio fallito.'));

    final failure = await container
        .read(pushNotificationControllerProvider.notifier)
        .sendTestNotification();

    expect(failure, isA<UnexpectedFailure>());
  });
}
