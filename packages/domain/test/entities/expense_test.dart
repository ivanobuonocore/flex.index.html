import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Expense', () {
    test('copyWith aggiorna solo i campi indicati', () {
      final expense = Expense(
        id: 'e1',
        workspaceId: 'w1',
        chatId: 'c1',
        description: 'Barbiere',
        amountCents: 2300,
        occurredAt: DateTime.utc(2026, 6, 15),
        status: ExpenseStatus.pending,
        createdByAi: true,
        createdAt: DateTime.utc(2026, 6, 15),
      );

      final confirmed = expense.copyWith(status: ExpenseStatus.confirmed);

      expect(confirmed.status, ExpenseStatus.confirmed);
      expect(confirmed.description, expense.description);
      expect(confirmed.amountCents, expense.amountCents);
      expect(confirmed.id, expense.id);
      expect(confirmed.workspaceId, expense.workspaceId);
      expect(confirmed.chatId, expense.chatId);
      expect(confirmed.createdByAi, expense.createdByAi);
    });

    test('due Expense con stessi campi sono uguali per valore', () {
      final a = Expense(
        id: 'e1',
        workspaceId: 'w1',
        description: 'Supermercato',
        amountCents: 3500,
        occurredAt: DateTime.utc(2026, 6, 10),
        status: ExpenseStatus.confirmed,
        createdAt: DateTime.utc(2026, 6, 10),
      );
      final b = Expense(
        id: 'e1',
        workspaceId: 'w1',
        description: 'Supermercato',
        amountCents: 3500,
        occurredAt: DateTime.utc(2026, 6, 10),
        status: ExpenseStatus.confirmed,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
