import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pip_mobile/features/notifications/data/base64_url_codec.dart';

void main() {
  test('decodeBase64Url/encodeBase64Url fanno un round-trip esatto', () {
    final bytes = Uint8List.fromList(List.generate(65, (i) => i));
    final encoded = encodeBase64Url(bytes);

    expect(encoded.contains('='), isFalse);
    expect(decodeBase64Url(encoded), bytes);
  });

  test('decodeBase64Url decodifica una vera chiave pubblica VAPID (65 byte, '
      'punto EC non compresso)', () {
    // Generata con `npx web-push generate-vapid-keys` per la verifica di
    // questa slice (docs/database/README.md, "Notifiche push vere").
    const publicKey =
        'BCWs59-Utfv5YV1otCqDeFBPI6WXZiZAxdJoSN3nhlG5vg4702DD4vbjP1YubkPL2q9egJ3K0c_nSxhDXjoLaZw';

    final bytes = decodeBase64Url(publicKey);

    expect(bytes.length, 65);
    expect(bytes.first, 0x04); // prefisso standard punto EC non compresso
    expect(encodeBase64Url(bytes), publicKey);
  });

  test('decodeBase64Url accetta input senza padding e con caratteri -/_', () {
    // 'auth' base64url tipico da PushSubscription.getKey('auth') (16 byte).
    final bytes = Uint8List.fromList([
      255, 254, 253, 252, 251, 250, 249, 248, //
      247, 246, 245, 244, 243, 242, 241, 240,
    ]);
    final encoded = encodeBase64Url(bytes);

    expect(decodeBase64Url(encoded), bytes);
  });
}
