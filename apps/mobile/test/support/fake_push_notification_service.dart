import 'package:pip_mobile/features/notifications/data/push_notification_service.dart';

class FakePushNotificationService implements PushNotificationService {
  PushSupportStatus statusResult = PushSupportStatus.notSubscribed;
  PushSubscriptionKeys? subscribeResult;
  String? lastVapidPublicKey;

  @override
  Future<PushSupportStatus> checkStatus() async => statusResult;

  @override
  Future<PushSubscriptionKeys?> subscribe(String vapidPublicKey) async {
    lastVapidPublicKey = vapidPublicKey;
    return subscribeResult;
  }
}
