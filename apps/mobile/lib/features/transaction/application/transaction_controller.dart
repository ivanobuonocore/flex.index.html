import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';
import '../../budget/application/budget_controller.dart';
import '../../workspace/application/workspace_controller.dart';

/// Transazioni (entrate/uscite) di un Workspace, in tempo reale (Software
/// Architecture, "Sincronizzazione" — Realtime lato Supabase). `null` =
/// transazioni di tutti i Workspace dell'utente (schermata Bilancio globale).
final transactionsProvider =
    StreamProvider.autoDispose.family<List<Transaction>, String?>(
  (ref, workspaceId) =>
      ref.watch(transactionRepositoryProvider).watchTransactions(workspaceId),
);

final transactionFormControllerProvider =
    AsyncNotifierProvider.autoDispose<TransactionFormController, void>(
        TransactionFormController.new);

class TransactionFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Failure?> create({
    required String workspaceId,
    required TransactionType type,
    required String description,
    required int amountCents,
    required DateTime occurredAt,
    TransactionCategory category = TransactionCategory.altro,
    List<String> tags = const [],
  }) async {
    state = const AsyncLoading();
    final result =
        await ref.read(transactionRepositoryProvider).createTransaction(
              workspaceId: workspaceId,
              type: type,
              description: description,
              amountCents: amountCents,
              occurredAt: occurredAt,
              category: category,
              tags: tags,
            );
    state = const AsyncData(null);
    if (result is Ok<Transaction> && type == TransactionType.expense) {
      await _maybeAlertBudget(
        workspaceId: workspaceId,
        category: category,
        amountCents: amountCents,
      );
    }
    return result.fold((_) => null, (failure) => failure);
  }

  Future<Failure?> updateTransaction(Transaction transaction) async {
    state = const AsyncLoading();
    final result = await ref
        .read(transactionRepositoryProvider)
        .updateTransaction(transaction);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  /// `pending` -> `confirmed` (AI Constitution, Principio 1): solo da qui una
  /// transazione suggerita dall'AI inizia a contare nel saldo.
  Future<Failure?> confirm(String transactionId) async {
    state = const AsyncLoading();
    final result = await ref
        .read(transactionRepositoryProvider)
        .confirmTransaction(transactionId);
    state = const AsyncData(null);
    if (result is Ok<Transaction>) {
      final confirmed = result.value;
      if (confirmed.type == TransactionType.expense) {
        await _maybeAlertBudget(
          workspaceId: confirmed.workspaceId,
          category: confirmed.category,
          amountCents: confirmed.amountCents,
        );
      }
    }
    return result.fold((_) => null, (failure) => failure);
  }

  /// Usato sia per "scarta" (transazione pending) sia per "elimina"
  /// (transazione confermata) — stessa operazione, label diversa in UI.
  Future<Failure?> delete(String transactionId) async {
    state = const AsyncLoading();
    final result = await ref
        .read(transactionRepositoryProvider)
        .deleteTransaction(transactionId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  /// [documentId] `null` rimuove l'allegato (richiesta esplicita
  /// dell'utente: "scontrino allegato alla Transazione").
  Future<Failure?> attachDocument({
    required String transactionId,
    required String? documentId,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(transactionRepositoryProvider).attachDocument(
          transactionId: transactionId,
          documentId: documentId,
        );
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  /// Notifica push se la spesa appena creata/confermata fa superare l'80% o
  /// il 100% del budget della sua categoria (integrazione richiesta
  /// esplicitamente: "notifica push su budget quasi superato"). Interamente
  /// best-effort, come [BudgetRepository.checkBudgetAlert]: nessun errore qui
  /// (provider non disponibili, budget non ancora caricati) deve mai
  /// impedire il successo di create/confirm già ritornato al chiamante.
  /// [spentBeforeCents] è la spesa del mese già confermata, letta dallo
  /// stream (quindi non ancora aggiornata con questa transazione): sommare
  /// direttamente [amountCents] evita di dipendere dal tempismo del
  /// realtime.
  Future<void> _maybeAlertBudget({
    required String workspaceId,
    required TransactionCategory category,
    required int amountCents,
  }) async {
    try {
      final workspaces = ref.read(workspacesProvider).value ?? const [];
      Workspace? workspace;
      for (final w in workspaces) {
        if (w.id == workspaceId) {
          workspace = w;
          break;
        }
      }
      // I Budget sono valutati solo sui Workspace personali (stesso
      // aggregato di `_BudgetSection` in balance_overview_screen.dart): una
      // spesa in un Bilancio condiviso non deve innescare una notifica.
      if (workspace == null || workspace.category == sharedBalanceCategory) {
        return;
      }

      final budgets = ref.read(budgetsProvider).value ?? const [];
      CategoryBudget? budget;
      for (final b in budgets) {
        if (b.category == category) {
          budget = b;
          break;
        }
      }
      if (budget == null) return;

      final allTransactions =
          ref.read(transactionsProvider(null)).value ?? const [];
      final personalWorkspaceIds = workspaces
          .where((w) => w.category != sharedBalanceCategory)
          .map((w) => w.id)
          .toSet();
      final confirmed = confirmedThisMonth(
        allTransactions
            .where((t) => personalWorkspaceIds.contains(t.workspaceId))
            .toList(growable: false),
      );
      final spentBeforeCents = totalExpenseCents(
        confirmed.where((t) => t.category == category),
      );

      await ref.read(budgetRepositoryProvider).checkBudgetAlert(
            budgetId: budget.id,
            category: category,
            spentCents: spentBeforeCents + amountCents,
            limitCents: budget.monthlyLimitCents,
          );
    } catch (_) {
      // Ignorato deliberatamente: vedi commento sopra.
    }
  }
}

/// Transazioni confermate che ricadono nel mese di [now] (default: oggi).
/// Pure, testabile senza Riverpod.
List<Transaction> confirmedThisMonth(List<Transaction> transactions,
    {DateTime? now}) {
  final reference = now ?? DateTime.now();
  return transactions
      .where((t) =>
          t.status == TransactionStatus.confirmed &&
          t.occurredAt.year == reference.year &&
          t.occurredAt.month == reference.month)
      .toList(growable: false);
}

/// Transazioni in attesa di conferma, **non** filtrate per mese: una
/// transazione pending di un mese diverso da quello corrente deve restare
/// visibile finché l'utente non la conferma o la scarta.
List<Transaction> pendingTransactions(List<Transaction> transactions) {
  return transactions
      .where((t) => t.status == TransactionStatus.pending)
      .toList(growable: false);
}

/// Somma degli importi (in centesimi) delle entrate indicate.
int totalIncomeCents(Iterable<Transaction> transactions) {
  return transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amountCents);
}

/// Somma degli importi (in centesimi) delle uscite indicate.
int totalExpenseCents(Iterable<Transaction> transactions) {
  return transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (sum, t) => sum + t.amountCents);
}

/// Saldo (entrate − uscite) delle transazioni indicate.
int balanceCents(Iterable<Transaction> transactions) {
  return totalIncomeCents(transactions) - totalExpenseCents(transactions);
}

/// Somma degli importi (in centesimi) per categoria, tra le transazioni
/// indicate — usata per il dettaglio "per categoria" del Bilancio (richiesta
/// esplicita dell'utente: dettaglio al tocco di Entrate/Uscite). Il chiamante
/// filtra prima per tipo (entrata/uscita); qui si aggrega soltanto.
Map<TransactionCategory, int> amountCentsByCategory(
    Iterable<Transaction> transactions) {
  final totals = <TransactionCategory, int>{};
  for (final t in transactions) {
    totals[t.category] = (totals[t.category] ?? 0) + t.amountCents;
  }
  return totals;
}

/// Percentuale di variazione tra due importi (richiesta esplicita
/// dell'utente: "confronto col mese precedente"). `null` se [previous] è 0:
/// nessun confronto sensato ("+∞%"), non una divisione per zero mascherata.
double? percentChange({required int current, required int previous}) {
  if (previous == 0) return null;
  return (current - previous) / previous.abs() * 100;
}

/// Gli ultimi [months] mesi fino a [reference] incluso, dal più vecchio al
/// più recente — usati per il grafico "andamento nel tempo" (richiesta
/// esplicita dell'utente).
List<DateTime> lastMonths(DateTime reference, int months) {
  return List.generate(
    months,
    (i) => DateTime(reference.year, reference.month - (months - 1 - i)),
    growable: false,
  );
}

/// Entrate/uscite confermate di un singolo mese, per il grafico "andamento
/// nel tempo".
class MonthlyTotals {
  const MonthlyTotals({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
  });

  final DateTime month;
  final int incomeCents;
  final int expenseCents;
}

/// Applica [confirmedThisMonth]/[totalIncomeCents]/[totalExpenseCents] a
/// ciascuno dei [months] — pure, testabile senza Riverpod, stessa logica già
/// usata altrove in questo file per un singolo mese.
List<MonthlyTotals> monthlyTotals(
  List<Transaction> transactions,
  List<DateTime> months,
) {
  return months.map((month) {
    final confirmed = confirmedThisMonth(transactions, now: month);
    return MonthlyTotals(
      month: month,
      incomeCents: totalIncomeCents(confirmed),
      expenseCents: totalExpenseCents(confirmed),
    );
  }).toList(growable: false);
}

/// Speso (o incassato) in una singola categoria per ciascuno dei [months]
/// (richiesta esplicita dell'utente: "andamento per categoria nel tempo") —
/// stessa composizione di [monthlyTotals], solo filtrata a un tipo e una
/// categoria tramite [amountCentsByCategory] invece del totale entrate/uscite.
/// [type] richiesto (non dedotto): lo stesso filtro che il chiamante applica
/// già prima di costruire `incomeByCategory`/`expenseByCategory` in
/// `balance_overview_screen.dart` — qui esplicito, per non sommare per
/// sbaglio entrate e uscite della stessa categoria nello stesso mese.
List<int> categoryMonthlyTotals(
  List<Transaction> transactions,
  List<DateTime> months,
  TransactionCategory category, {
  required TransactionType type,
}) {
  return months.map((month) {
    final confirmed = confirmedThisMonth(transactions, now: month)
        .where((t) => t.type == type);
    return amountCentsByCategory(confirmed)[category] ?? 0;
  }).toList(growable: false);
}

/// Estrapolazione lineare della spesa a fine mese (integrazione richiesta
/// esplicitamente): proiezione di quanto già speso su tutti i giorni del
/// mese, non un modello predittivo — ha senso solo per il mese in corso (il
/// chiamante decide quando mostrarla, questa funzione non lo sa). `null` il
/// primo giorno del mese: nessuna proiezione sensata da un solo giorno di
/// dati (dividerebbe per un campione troppo piccolo, amplificando rumore).
int? projectedMonthEndExpenseCents({
  required int spentSoFarCents,
  required DateTime now,
}) {
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final dayOfMonth = now.day;
  if (dayOfMonth <= 1) return null;
  return (spentSoFarCents / dayOfMonth * daysInMonth).round();
}

/// Uscite confermate per ciascun giorno di [month] (richiesta esplicita
/// dell'utente: "heatmap delle spese nel Bilancio") — chiave = giorno del
/// mese (1-31), assente se quel giorno non ha alcuna uscita confermata. Pure,
/// testabile senza Riverpod, stessa composizione di [confirmedThisMonth]/
/// [totalExpenseCents] già usata altrove in questo file.
Map<int, int> dailyExpenseTotals(
    List<Transaction> transactions, DateTime month) {
  final confirmed = confirmedThisMonth(transactions, now: month)
      .where((t) => t.type == TransactionType.expense);
  final totals = <int, int>{};
  for (final t in confirmed) {
    final day = t.occurredAt.day;
    totals[day] = (totals[day] ?? 0) + t.amountCents;
  }
  return totals;
}
