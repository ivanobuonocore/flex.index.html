import 'dart:convert';
import 'dart:typed_data';

/// Codifica/decodifica base64url senza padding (RFC 4648 §5) — lo stesso
/// formato usato dalle chiavi VAPID e dalle `PushSubscription` del browser
/// (Web Push, RFC 8291). Funzioni pure, nessuna dipendenza da `dart:js_interop`:
/// a differenza del resto della feature Notifiche, sono testabili con
/// `flutter test` anche senza un browser reale.

Uint8List decodeBase64Url(String value) =>
    base64Url.decode(base64Url.normalize(value));

String encodeBase64Url(Uint8List bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
