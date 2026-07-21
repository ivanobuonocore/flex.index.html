import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Message', () {
    final timestamp = DateTime.utc(2026, 1, 1);

    test('pendingTransactionIds di default è vuoto', () {
      final message = Message(
        id: 'm1',
        chatId: 'c1',
        role: MessageRole.ai,
        content: 'Ciao',
        timestamp: timestamp,
      );

      expect(message.pendingTransactionIds, isEmpty);
    });

    test('due messaggi con stessi pendingTransactionIds sono uguali', () {
      final a = Message(
        id: 'm1',
        chatId: 'c1',
        role: MessageRole.ai,
        content: 'Ho registrato una spesa in attesa di conferma.',
        timestamp: timestamp,
        pendingTransactionIds: const ['t1', 't2'],
      );
      final b = Message(
        id: 'm1',
        chatId: 'c1',
        role: MessageRole.ai,
        content: 'Ho registrato una spesa in attesa di conferma.',
        timestamp: timestamp,
        pendingTransactionIds: const ['t1', 't2'],
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test(
        'pendingTransactionIds diverso distingue due messaggi altrimenti identici',
        () {
      final withIds = Message(
        id: 'm1',
        chatId: 'c1',
        role: MessageRole.ai,
        content: 'Ciao',
        timestamp: timestamp,
        pendingTransactionIds: const ['t1'],
      );
      final withoutIds = Message(
        id: 'm1',
        chatId: 'c1',
        role: MessageRole.ai,
        content: 'Ciao',
        timestamp: timestamp,
      );

      expect(withIds, isNot(equals(withoutIds)));
    });
  });
}
