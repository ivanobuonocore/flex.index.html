import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Transaction', () {
    test('copyWith aggiorna solo i campi indicati', () {
      final transaction = Transaction(
        id: 't1',
        workspaceId: 'w1',
        chatId: 'c1',
        type: TransactionType.expense,
        description: 'Barbiere',
        amountCents: 2300,
        occurredAt: DateTime.utc(2026, 6, 15),
        status: TransactionStatus.pending,
        createdByAi: true,
        createdAt: DateTime.utc(2026, 6, 15),
      );

      final confirmed = transaction.copyWith(status: TransactionStatus.confirmed);

      expect(confirmed.status, TransactionStatus.confirmed);
      expect(confirmed.description, transaction.description);
      expect(confirmed.amountCents, transaction.amountCents);
      expect(confirmed.type, transaction.type);
      expect(confirmed.id, transaction.id);
      expect(confirmed.workspaceId, transaction.workspaceId);
      expect(confirmed.chatId, transaction.chatId);
      expect(confirmed.createdByAi, transaction.createdByAi);
    });

    test('due Transaction con stessi campi sono uguali per valore', () {
      final a = Transaction(
        id: 't1',
        workspaceId: 'w1',
        type: TransactionType.income,
        description: 'Stipendio',
        amountCents: 150000,
        occurredAt: DateTime.utc(2026, 6, 1),
        status: TransactionStatus.confirmed,
        createdAt: DateTime.utc(2026, 6, 1),
      );
      final b = Transaction(
        id: 't1',
        workspaceId: 'w1',
        type: TransactionType.income,
        description: 'Stipendio',
        amountCents: 150000,
        occurredAt: DateTime.utc(2026, 6, 1),
        status: TransactionStatus.confirmed,
        createdAt: DateTime.utc(2026, 6, 1),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('type diverso distingue due transazioni altrimenti identiche', () {
      Transaction withType(TransactionType type) => Transaction(
            id: 't1',
            workspaceId: 'w1',
            type: type,
            description: 'Rimborso',
            amountCents: 1000,
            occurredAt: DateTime.utc(2026, 6, 1),
            status: TransactionStatus.confirmed,
            createdAt: DateTime.utc(2026, 6, 1),
          );

      expect(withType(TransactionType.expense) == withType(TransactionType.income), isFalse);
    });
  });
}
