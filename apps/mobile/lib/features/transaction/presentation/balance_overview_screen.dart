import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/coach_mark.dart';
import '../../../shared/widgets/colorful_icon_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/skeleton_list.dart';
import '../../budget/application/budget_controller.dart';
import '../../workspace/application/workspace_controller.dart';
import '../application/transaction_category_meta.dart';
import '../application/transaction_controller.dart';

const _italianMonths = [
  'Gennaio',
  'Febbraio',
  'Marzo',
  'Aprile',
  'Maggio',
  'Giugno',
  'Luglio',
  'Agosto',
  'Settembre',
  'Ottobre',
  'Novembre',
  'Dicembre',
];

/// Bilancio globale (docs/product/06-information-architecture.md — nuova
/// quinta voce di navigazione, richiesta esplicita dell'utente): a differenza
/// di [TransactionReportScreen] (un solo Workspace), qui `workspaceId` è
/// sempre `null` — aggrega le transazioni di **tutti** i Workspace
/// dell'utente in un unico grafico a torta entrate/uscite, così le spese
/// scritte in Chat (in qualsiasi Workspace, o privatamente) confluiscono in
/// un prospetto unico. Stesso principio "l'AI suggerisce, l'utente decide":
/// nessuna transazione pending conta nel saldo o nel grafico.
///
/// Esclude i Bilanci condivisi ([sharedBalanceCategory]) — Fase 3, "Bilancio
/// condiviso": richiesta esplicita dell'utente di **due** Bilanci separati,
/// uno personale e uno condiviso, non un unico totale che li confonda. Senza
/// questo filtro, le transazioni di un Bilancio condiviso (proprio o di cui
/// si è membri) finirebbero comunque qui sotto RLS, dato che
/// `watchTransactions(null)` non filtra per Workspace lato applicazione.
class BalanceOverviewScreen extends ConsumerStatefulWidget {
  const BalanceOverviewScreen({super.key});

  @override
  ConsumerState<BalanceOverviewScreen> createState() =>
      _BalanceOverviewScreenState();
}

class _BalanceOverviewScreenState extends ConsumerState<BalanceOverviewScreen> {
  // `null` = mese corrente: non si fissa mai un mese esplicito di default,
  // così la schermata segue il calendario reale finché l'utente non sceglie
  // uno storico (richiesta esplicita dell'utente: "vorrei che il Bilancio
  // avesse anche uno storico, una tendina dove poter scegliere il mese").
  DateTime? _selectedMonth;

  // Ricerca nelle Transazioni confermate (richiesta esplicita dell'utente,
  // al posto della tab Ricerca tolta dalla barra di navigazione: "la ricerca
  // potrei comunque inserirla nel bilancio per ricercare le spese"). Filtra
  // solo l'elenco sotto, non il saldo/grafico/budget — stesso principio già
  // usato dalla tendina del mese per il solo elenco "In attesa di conferma".
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Filtro per categoria nelle Transazioni confermate (integrazione richiesta
  // esplicitamente), in aggiunta alla ricerca testuale già presente — stesso
  // principio già usato dai tag delle Note: `null` = nessun filtro, tutte le
  // categorie.
  TransactionCategory? _filterCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider(null));
    final workspacesAsync = ref.watch(workspacesProvider);

    return Scaffold(
      appBar: GradientAppBar(
        title: const Text('Bilancio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Bilancio condiviso',
            onPressed: () => context.push('/balance/shared'),
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const SkeletonList(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare il bilancio.',
          onRetry: () => ref.invalidate(transactionsProvider(null)),
        ),
        data: (allTransactions) {
          final now = DateTime.now();
          final workspaces = workspacesAsync.value ?? const [];
          final personalWorkspaceIds = workspaces
              .where((w) => w.category != sharedBalanceCategory)
              .map((w) => w.id)
              .toSet();
          final transactions = allTransactions
              .where((t) => personalWorkspaceIds.contains(t.workspaceId))
              .toList(growable: false);

          // Ogni mese in cui esiste almeno una transazione confermata, più
          // il mese corrente (sempre presente, anche senza storico ancora):
          // popola la tendina dello storico.
          final currentMonth = DateTime(now.year, now.month);
          final availableMonths = <DateTime>{
            currentMonth,
            for (final t in transactions)
              if (t.status == TransactionStatus.confirmed)
                DateTime(t.occurredAt.year, t.occurredAt.month),
          }.toList()
            ..sort((a, b) => b.compareTo(a));
          final selectedMonth = _selectedMonth ?? currentMonth;

          final confirmed =
              confirmedThisMonth(transactions, now: selectedMonth);
          final pending = pendingTransactions(transactions);

          if (confirmed.isEmpty &&
              pending.isEmpty &&
              availableMonths.length <= 1) {
            return const EmptyState(
              icon: Icons.pie_chart_outline,
              color: AppColors.categoryBilancio,
              title: 'Nessuna transazione ancora',
              message:
                  'Scrivi una spesa o un\'entrata in una Chat (es. "barbiere 23€") oppure '
                  'aggiungila dal Bilancio di un Workspace: qui troverai il quadro d\'insieme.',
            );
          }

          final workspaceNames = <String, String>{
            for (final workspace in workspaces) workspace.id: workspace.name,
          };

          final income = totalIncomeCents(confirmed);
          final expense = totalExpenseCents(confirmed);
          final balance = balanceCents(confirmed);
          final incomeByCategory = amountCentsByCategory(
              confirmed.where((t) => t.type == TransactionType.income));
          final expenseByCategory = amountCentsByCategory(
              confirmed.where((t) => t.type == TransactionType.expense));

          // Confronto col mese precedente (richiesta esplicita dell'utente) e
          // andamento degli ultimi 6 mesi, calcolati sul mese selezionato
          // nella tendina (non sempre il mese corrente): stessa logica pura
          // già usata sopra, solo applicata anche al mese prima e allo
          // storico.
          final previousMonth =
              DateTime(selectedMonth.year, selectedMonth.month - 1);
          final previousBalance = balanceCents(
              confirmedThisMonth(transactions, now: previousMonth));
          final balanceChangePercent =
              percentChange(current: balance, previous: previousBalance);
          final trend =
              monthlyTotals(transactions, lastMonths(selectedMonth, 6));

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MonthPicker(
                    selectedMonth: selectedMonth,
                    availableMonths: availableMonths,
                    onChanged: (month) =>
                        setState(() => _selectedMonth = month),
                  ),
                  IconButton(
                    icon: const Icon(Icons.ios_share_outlined),
                    tooltip: 'Condividi riepilogo',
                    onPressed: () => _showExportSheet(
                      context,
                      month: selectedMonth,
                      balanceCents: balance,
                      incomeCents: income,
                      expenseCents: expense,
                      incomeByCategory: incomeByCategory,
                      expenseByCategory: expenseByCategory,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tutti i Workspace',
                style: AppTypography.caption.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _BalanceHeroCard(
                balanceCents: balance,
                incomeCents: income,
                expenseCents: expense,
                incomeByCategory: incomeByCategory,
                expenseByCategory: expenseByCategory,
                previousMonthPercentChange: balanceChangePercent,
                transactions: transactions,
                selectedMonth: selectedMonth,
              ),
              if (expenseByCategory.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                // Pulsante esplicito (richiesta dell'utente: "vorrei si
                // potesse vedere magari con un tasto la somma di tutte le
                // categorie di spese fatte") — prima l'unico modo per
                // arrivare allo stesso dettaglio era toccare la pillola
                // "Uscite" dell'hero, un gesto poco scopribile perché non
                // sembra un pulsante.
                OutlinedButton.icon(
                  onPressed: () => _showCategoryBreakdown(
                    context,
                    title: 'Categorie di spesa',
                    byCategory: expenseByCategory,
                    transactions: transactions,
                    selectedMonth: selectedMonth,
                    type: TransactionType.expense,
                  ),
                  icon: const Icon(Icons.category_outlined),
                  label: const Text('Categorie di spesa'),
                ),
              ],
              if (selectedMonth == currentMonth) ...[
                Builder(builder: (context) {
                  final projected = projectedMonthEndExpenseCents(
                    spentSoFarCents: expense,
                    now: now,
                  );
                  if (projected == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: _ProjectedExpenseCard(projectedCents: projected),
                  );
                }),
              ],
              const SizedBox(height: AppSpacing.md),
              _BalancePieChart(incomeCents: income, expenseCents: expense),
              const SizedBox(height: AppSpacing.lg),
              _TrendChart(trend: trend),
              const SizedBox(height: AppSpacing.lg),
              CoachMark(
                id: 'bilancio_heatmap',
                message: 'Ogni casella è un giorno: più intenso il colore, '
                    'più hai speso quel giorno.',
                child: _ExpenseHeatmap(
                  month: selectedMonth,
                  dailyTotals: dailyExpenseTotals(transactions, selectedMonth),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _BudgetSection(expenseByCategory: expenseByCategory),
              if (pending.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('In attesa di conferma', style: AppTypography.heading3),
                const SizedBox(height: AppSpacing.sm),
                for (final transaction in pending) ...[
                  _PendingTransactionTile(
                    transaction: transaction,
                    workspaceName:
                        workspaceNames[transaction.workspaceId] ?? 'Workspace',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Transazioni confermate', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.sm),
              if (confirmed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('Nessuna transazione confermata questo mese.'),
                )
              else ...[
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cerca per descrizione o tag…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border:
                        OutlineInputBorder(borderRadius: AppRadii.buttonRadius),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                Builder(builder: (context) {
                  // Solo le categorie effettivamente presenti tra le
                  // transazioni confermate di questo mese, non l'intero set
                  // fisso — una striscia con voci sempre vuote non aiuta a
                  // filtrare nulla.
                  final categoriesPresent = <TransactionCategory>{
                    for (final t in confirmed) t.category,
                  }.toList()
                    ..sort((a, b) => TransactionCategoryMeta.of(a)
                        .label
                        .compareTo(TransactionCategoryMeta.of(b).label));

                  if (categoriesPresent.length <= 1) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categoriesPresent.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final category = categoriesPresent[index];
                          final meta = TransactionCategoryMeta.of(category);
                          final isSelected = category == _filterCategory;
                          return FilterChip(
                            label: Text(meta.label),
                            avatar: ColorfulIconBadge(
                              icon: meta.icon,
                              color: meta.color,
                              size: 22,
                            ),
                            selected: isSelected,
                            onSelected: (_) => setState(
                              () => _filterCategory =
                                  isSelected ? null : category,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),
                Builder(builder: (context) {
                  final query = _searchQuery.trim().toLowerCase();
                  final category = _filterCategory;
                  final visibleConfirmed = confirmed.where((t) {
                    final matchesQuery = query.isEmpty ||
                        t.description.toLowerCase().contains(query) ||
                        t.tags.any((tag) => tag.toLowerCase().contains(query));
                    final matchesCategory =
                        category == null || t.category == category;
                    return matchesQuery && matchesCategory;
                  }).toList(growable: false);

                  if (visibleConfirmed.isEmpty) {
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Text(_searchQuery.trim().isEmpty
                          ? 'Nessun risultato per questa categoria.'
                          : 'Nessun risultato per "${_searchController.text}".'),
                    );
                  }

                  return Column(
                    children: [
                      for (final transaction in visibleConfirmed) ...[
                        _ConfirmedTransactionTile(
                          transaction: transaction,
                          workspaceName:
                              workspaceNames[transaction.workspaceId] ??
                                  'Workspace',
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Tendina del mese di riferimento (redesign — richiesta esplicita
/// dell'utente: "uno storico, una tendina dove poter scegliere il mese...
/// che si colleghi al grafico"): [BalanceOverviewScreen] ricalcola hero,
/// grafico ed elenco confermate sul mese scelto qui — le transazioni in
/// attesa di conferma restano invece sempre visibili indipendentemente dal
/// mese (non è filtrabile una cosa che deve ancora essere confermata).
class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.selectedMonth,
    required this.availableMonths,
    required this.onChanged,
  });

  final DateTime selectedMonth;
  final List<DateTime> availableMonths;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DateTime>(
      initialValue: selectedMonth,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final month in availableMonths)
          PopupMenuItem(value: month, child: Text(_label(month))),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Panoramica ${_label(selectedMonth)}',
              style: AppTypography.heading3),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.expand_more,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        ],
      ),
    );
  }

  String _label(DateTime month) =>
      '${_italianMonths[month.month - 1]} ${month.year}';
}

/// Saldo del mese in evidenza, con gradiente "premium" (redesign estetico 2.0
/// — richiesta esplicita dell'utente: "molto tecnologica", "profondità"):
/// stessa famiglia cromatica dell'AppBar e della Chat, per un linguaggio
/// visivo coerente in tutta l'app — al posto della Card piatta precedente.
class _BalanceHeroCard extends StatelessWidget {
  const _BalanceHeroCard({
    required this.balanceCents,
    required this.incomeCents,
    required this.expenseCents,
    required this.incomeByCategory,
    required this.expenseByCategory,
    required this.previousMonthPercentChange,
    required this.transactions,
    required this.selectedMonth,
  });

  final int balanceCents;
  final int incomeCents;
  final int expenseCents;
  final Map<TransactionCategory, int> incomeByCategory;
  final Map<TransactionCategory, int> expenseByCategory;

  /// `null` quando il mese precedente ha saldo 0 (nessun confronto
  /// sensato — vedi `percentChange`), non mostrato in quel caso.
  final double? previousMonthPercentChange;

  /// Passate solo per l'andamento per categoria (richiesta esplicita
  /// dell'utente), aperto dal tocco su una riga di `_CategoryBreakdownTile`
  /// dentro `_showCategoryBreakdown` — non usate altrove in questo widget.
  final List<Transaction> transactions;
  final DateTime selectedMonth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.cardPremiumRadius,
        boxShadow: AppShadows.glow(
          color: AppColors.heroGradient.first,
          isDark: isDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo del mese',
            style: AppTypography.caption
                .copyWith(color: Colors.white.withOpacity(0.85)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _formatSignedAmount(balanceCents),
            style: AppTypography.heading1.copyWith(color: Colors.white),
          ),
          if (previousMonthPercentChange != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _PercentChangeBadge(percentChange: previousMonthPercentChange!),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _HeroStatPill(
                  emoji: '💰',
                  emojiColor: const Color(0xFF16A34A),
                  label: 'Entrate',
                  amountCents: incomeCents,
                  onTap: incomeCents == 0
                      ? null
                      : () => _showCategoryBreakdown(
                            context,
                            title: 'Entrate per categoria',
                            byCategory: incomeByCategory,
                            transactions: transactions,
                            selectedMonth: selectedMonth,
                            type: TransactionType.income,
                          ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeroStatPill(
                  emoji: '💸',
                  emojiColor: const Color(0xFFEF4444),
                  label: 'Uscite',
                  amountCents: expenseCents,
                  onTap: expenseCents == 0
                      ? null
                      : () => _showCategoryBreakdown(
                            context,
                            title: 'Uscite per categoria',
                            byCategory: expenseByCategory,
                            transactions: transactions,
                            selectedMonth: selectedMonth,
                            type: TransactionType.expense,
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Previsione di fine mese (integrazione richiesta esplicitamente) — solo
/// per il mese in corso, mai su uno storico (il chiamante lo garantisce
/// mostrando questa card solo quando `selectedMonth == currentMonth`).
class _ProjectedExpenseCard extends StatelessWidget {
  const _ProjectedExpenseCard({required this.projectedCents});

  final int projectedCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadii.standardRadius,
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Proiezione di fine mese: ${_formatAmount(projectedCents)}',
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge "vs mese scorso" (richiesta esplicita dell'utente: "confronto col
/// mese precedente") — saldo migliorato (percentuale ≥ 0) in verde con
/// freccia su, peggiorato in rosso con freccia giù. Sfondo bianco
/// traslucido come [_HeroStatPill]: stessa ragione, il verde/rosso pieno
/// perderebbe leggibilità sul gradiente dell'hero.
class _PercentChangeBadge extends StatelessWidget {
  const _PercentChangeBadge({required this.percentChange});

  final double percentChange;

  @override
  Widget build(BuildContext context) {
    final isImprovement = percentChange >= 0;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: AppRadii.buttonRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isImprovement ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: isImprovement ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 2),
          Text(
            '${percentChange.abs().toStringAsFixed(0)}% vs mese scorso',
            style: AppTypography.caption
                .copyWith(color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }
}

/// Pillola statistica dentro l'hero del saldo (Entrate/Uscite) — sfondo
/// bianco traslucido, con emoji native e colorate: sono più immediate e
/// mantengono il tono caldo dell'app. Tocco opzionale
/// (richiesta esplicita
/// dell'utente: dettaglio per categoria) — `null` quando non c'è nulla da
/// mostrare (importo a zero).
class _HeroStatPill extends StatelessWidget {
  const _HeroStatPill({
    required this.emoji,
    required this.emojiColor,
    required this.label,
    required this.amountCents,
    this.onTap,
  });

  final String emoji;
  final Color emojiColor;
  final String label;
  final int amountCents;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.buttonRadius,
      child: InkWell(
        borderRadius: AppRadii.buttonRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: AppRadii.buttonRadius,
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [emojiColor, emojiColor.withOpacity(0.66)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: emojiColor.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 19)),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTypography.caption
                          .copyWith(color: Colors.white.withOpacity(0.8)),
                    ),
                    Text(
                      _formatAmount(amountCents),
                      style: AppTypography.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right,
                    color: Colors.white.withOpacity(0.7), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Elenco delle categorie (ordinate per importo decrescente) di Entrate o
/// Uscite del mese in evidenza — richiesta esplicita dell'utente: un
/// dettaglio raggiungibile toccando le pillole Entrate/Uscite dell'hero, o il
/// pulsante "Categorie di spesa" subito sotto (stesso sheet, stesso dato).
/// Mostra sempre la somma di tutte le categorie in testa (richiesta esplicita
/// dell'utente: "vorrei si potesse vedere... la somma di tutte le categorie
/// di spese fatte") — prima veniva solo calcolata per le percentuali, senza
/// comparire mai come testo.
void _showCategoryBreakdown(
  BuildContext context, {
  required String title,
  required Map<TransactionCategory, int> byCategory,
  required List<Transaction> transactions,
  required DateTime selectedMonth,
  required TransactionType type,
}) {
  final entries = byCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final total = entries.fold(0, (sum, e) => sum + e.value);

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Totale: ${_formatAmount(total)}',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final entry in entries) ...[
              _CategoryBreakdownTile(
                category: entry.key,
                amountCents: entry.value,
                percent: total == 0 ? 0 : entry.value / total * 100,
                onTap: () => _showCategoryTrend(
                  context,
                  category: entry.key,
                  transactions: transactions,
                  selectedMonth: selectedMonth,
                  type: type,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ),
      ),
    ),
  );
}

class _CategoryBreakdownTile extends StatelessWidget {
  const _CategoryBreakdownTile({
    required this.category,
    required this.amountCents,
    required this.percent,
    required this.onTap,
  });

  final TransactionCategory category;
  final int amountCents;
  final double percent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = TransactionCategoryMeta.of(category);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.buttonRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              ColorfulIconBadge(
                icon: meta.icon,
                color: meta.color,
                size: 30,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(meta.label, style: AppTypography.body),
              ),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: AppTypography.caption.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _formatAmount(amountCents),
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right,
                  size: 18,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Andamento di una singola categoria negli ultimi 6 mesi (richiesta
/// esplicita dell'utente: "andamento per categoria nel tempo"), aperto
/// toccando una riga di [_CategoryBreakdownTile] — stessa finestra di
/// [_TrendChart] (`lastMonths(selectedMonth, 6)`), nessuna nuova
/// aggregazione: [categoryMonthlyTotals] compone funzioni pure già esistenti.
void _showCategoryTrend(
  BuildContext context, {
  required TransactionCategory category,
  required List<Transaction> transactions,
  required DateTime selectedMonth,
  required TransactionType type,
}) {
  final months = lastMonths(selectedMonth, 6);
  final values =
      categoryMonthlyTotals(transactions, months, category, type: type);
  final meta = TransactionCategoryMeta.of(category);

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ColorfulIconBadge(
                  icon: meta.icon,
                  color: meta.color,
                  size: 30,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('${meta.label} — ultimi 6 mesi',
                    style: AppTypography.heading3),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _CategoryTrendChart(
                months: months, values: values, color: meta.color),
          ],
        ),
      ),
    ),
  );
}

class _CategoryTrendChart extends StatefulWidget {
  const _CategoryTrendChart({
    required this.months,
    required this.values,
    required this.color,
  });

  final List<DateTime> months;
  final List<int> values;
  final Color color;

  @override
  State<_CategoryTrendChart> createState() => _CategoryTrendChartState();
}

class _CategoryTrendChartState extends State<_CategoryTrendChart> {
  // Le barre partono da altezza zero e crescono fino al valore reale al
  // primo caricamento (richiesta esplicita dell'utente: "animazione
  // d'ingresso sui grafici") — `BarChart` di fl_chart anima da solo la
  // transizione tra due `BarChartData` diversi, basta cambiare i valori dopo
  // il primo fotogramma.
  bool _grown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _grown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    final values = widget.values;
    final color = widget.color;
    final maxValue = values.fold<int>(0, (max, v) => v > max ? v : max);

    return SizedBox(
      height: 180,
      child: maxValue == 0
          ? const Center(
              child: Text('Nessun importo confermato in questo periodo.'),
            )
          : BarChart(
              swapAnimationDuration: const Duration(milliseconds: 600),
              swapAnimationCurve: Curves.easeOutCubic,
              BarChartData(
                maxY: maxValue * 1.2,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            _italianMonthsShort[months[index].month - 1],
                            style: AppTypography.caption,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: _grown ? values[i].toDouble() : 0,
                          color: color,
                          width: 12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _BalancePieChart extends StatefulWidget {
  const _BalancePieChart(
      {required this.incomeCents, required this.expenseCents});

  final int incomeCents;
  final int expenseCents;

  @override
  State<_BalancePieChart> createState() => _BalancePieChartState();
}

class _BalancePieChartState extends State<_BalancePieChart> {
  // Indice della fetta sotto il cursore/il dito (richiesta esplicita
  // dell'utente: "se passo con il cursore sul grafico vorrei che mi desse
  // qualche feedback"): `null` = nessuna, altrimenti l'indice nella lista
  // `slices` costruita in build.
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final incomeCents = widget.incomeCents;
    final expenseCents = widget.expenseCents;
    final total = incomeCents + expenseCents;

    if (total == 0) {
      return const Card(
        child: SizedBox(
          height: 180,
          child: Center(child: Text('Nessun importo confermato questo mese.')),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Un'unica palette in tutta l'app (richiesta esplicita dell'utente: "usa
    // una sola palette di colori blu che tende al viola") — stesso blu/viola
    // dell'hero del saldo e dell'AppBar, non i quattro colori del pulsante
    // Chat. Ogni fetta è un'unica tinta leggermente schiarita verso il
    // centro (non un colore piatto): un tocco di profondità che resta
    // comunque dentro la stessa famiglia cromatica — più sobrio di un
    // gradiente a due tinte diverse per fetta.
    final incomeColor = AppColors.heroGradient[0];
    final expenseColor = AppColors.heroGradient[1];

    // Costruita come lista esplicita (non due `if` diretti dentro
    // `sections`) perché l'indice della fetta toccata restituito da
    // fl_chart si riferisce a questa stessa lista, condizionale a seconda
    // di quali importi sono diversi da zero.
    final slices = [
      if (incomeCents > 0)
        (
          label: 'Entrate',
          amountCents: incomeCents,
          percent: incomeCents / total * 100,
          color: incomeColor,
        ),
      if (expenseCents > 0)
        (
          label: 'Uscite',
          amountCents: expenseCents,
          percent: expenseCents / total * 100,
          color: expenseColor,
        ),
    ];
    final touchedSlice = _touchedIndex != null && _touchedIndex! < slices.length
        ? slices[_touchedIndex!]
        : null;

    return Container(
      // Un solo alone, blu (AppShadows.glow, la stessa usata per l'hero del
      // saldo e l'AppBar) invece del multicolore: profondità senza perdere
      // la sobrietà richiesta ("più professionale").
      decoration: BoxDecoration(
        borderRadius: AppRadii.standardRadius,
        boxShadow: AppShadows.glow(color: incomeColor, isDark: isDark),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ombra sagomata sul donut stesso, non solo il rettangolo
                // della Card intorno (richiesta esplicita dell'utente: il
                // grafico "con profondità ed effetti"): una copia scura e
                // semi-trasparente dello stesso anello, spostata di pochi
                // pixel, simula un rilievo reale sulla forma — l'alone della
                // Card da solo resta rettangolare, non segue il cerchio.
                Transform.translate(
                  offset: const Offset(0, 6),
                  child: Opacity(
                    opacity: isDark ? 0.45 : 0.20,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 6,
                        centerSpaceRadius: 64,
                        sections: [
                          if (incomeCents > 0)
                            PieChartSectionData(
                              value: incomeCents.toDouble(),
                              color: Colors.black,
                              radius: 52,
                              showTitle: false,
                            ),
                          if (expenseCents > 0)
                            PieChartSectionData(
                              value: expenseCents.toDouble(),
                              color: Colors.black,
                              radius: 52,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                PieChart(
                  PieChartData(
                    sectionsSpace: 6,
                    // Anello più sottile (centro più ampio, fette più
                    // strette) invece di una torta piena: lettura più
                    // "dashboard premium" che "grafico a torta" classico.
                    centerSpaceRadius: 64,
                    // Feedback al passaggio del cursore/tocco (richiesta
                    // esplicita dell'utente): la fetta toccata "esce" di
                    // qualche pixel in più (raggio maggiore) e il centro del
                    // donut mostra il suo importo invece del netto — un
                    // riscontro immediato senza bisogno di un vero tooltip.
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        final index =
                            response?.touchedSection?.touchedSectionIndex;
                        final next =
                            (index != null && index >= 0) ? index : null;
                        if (next != _touchedIndex) {
                          setState(() => _touchedIndex = next);
                        }
                      },
                    ),
                    sections: [
                      for (var i = 0; i < slices.length; i++)
                        PieChartSectionData(
                          value: slices[i].amountCents.toDouble(),
                          // Gradiente radiale invece che a due punti lineare
                          // (richiesta esplicita dell'utente: più profondità
                          // "senza stravolgere il colore") — stessa tinta di
                          // ogni fetta, solo schiarita verso un fuoco in alto
                          // a sinistra e leggermente scurita verso il bordo
                          // esterno: dà l'impressione di una superficie
                          // sferica illuminata da una fonte di luce, non un
                          // colore piatto con un solo passaggio di tono.
                          gradient: RadialGradient(
                            center: const Alignment(-0.5, -0.6),
                            radius: 1.1,
                            colors: [
                              Color.lerp(slices[i].color, Colors.white, 0.45)!,
                              slices[i].color,
                              Color.lerp(slices[i].color, Colors.black, 0.12)!,
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                          title: '${slices[i].percent.toStringAsFixed(0)}%',
                          radius: _touchedIndex == i ? 60 : 52,
                          borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withOpacity(0.6),
                            width: 2,
                          ),
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                // Riflesso "vetro" sopra l'anello colorato (richiesta
                // esplicita dell'utente: più profondità "magari... non solo
                // ombre"): un unico arco bianco semi-trasparente, sfumato ai
                // due estremi, posizionato in alto — come un riflesso di
                // luce su una superficie curva e lucida. `IgnorePointer`
                // perché è puramente decorativo: il tocco deve continuare a
                // raggiungere l'anello colorato sotto (che gestisce
                // l'evidenziazione della fetta). Stessi `centerSpaceRadius`/
                // `radius` del grafico reale sopra: nello stesso `Stack`
                // centrato, fl_chart li dimensiona in modo identico, quindi
                // l'arco resta sempre perfettamente allineato all'anello
                // senza calcoli manuali di geometria.
                IgnorePointer(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 64,
                      // Il primo settore (72°, un quinto del cerchio) parte
                      // spostato indietro della metà della propria ampiezza,
                      // così risulta centrato esattamente in cima invece che
                      // partire da lì.
                      startDegreeOffset: -36,
                      sections: [
                        PieChartSectionData(
                          value: 20,
                          radius: 52,
                          showTitle: false,
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withOpacity(0),
                              Colors.white.withOpacity(0.4),
                              Colors.white.withOpacity(0),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                        PieChartSectionData(
                          value: 80,
                          radius: 52,
                          showTitle: false,
                          color: Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
                // Centro del donut: il netto del mese a colpo d'occhio, senza
                // dover sommare mentalmente le due fette. Un disco
                // "sollevato" con un sottile bordo blu (non colorato a caso:
                // stessa tinta delle fette) invece di testo semplice
                // sullo sfondo della Card.
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Un accenno dello stesso gradiente radiale "vetro" delle
                    // fette (richiesta esplicita dell'utente: "abbellimenti
                    // stilistici") — molto tenue, per non intaccare la
                    // leggibilità del testo sopra: un fuoco di luce quasi
                    // impercettibile in alto a sinistra invece di un colore
                    // piatto uniforme.
                    gradient: RadialGradient(
                      center: const Alignment(-0.4, -0.5),
                      radius: 1.2,
                      colors: [
                        Color.lerp(Theme.of(context).colorScheme.surface,
                            Colors.white, 0.12)!,
                        Theme.of(context).colorScheme.surface,
                      ],
                    ),
                    border: Border.all(
                      color: incomeColor.withOpacity(0.25),
                      width: 1.5,
                    ),
                    boxShadow: AppShadows.card(isDark: isDark),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: touchedSlice == null
                          ? [
                              Text('Netto', style: AppTypography.caption),
                              Text(
                                _formatSignedAmount(incomeCents - expenseCents),
                                style: AppTypography.heading3,
                              ),
                            ]
                          : [
                              Text(touchedSlice.label,
                                  style: AppTypography.caption
                                      .copyWith(color: touchedSlice.color)),
                              Text(
                                _formatAmount(touchedSlice.amountCents),
                                style: AppTypography.heading3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _italianMonthsShort = [
  'Gen',
  'Feb',
  'Mar',
  'Apr',
  'Mag',
  'Giu',
  'Lug',
  'Ago',
  'Set',
  'Ott',
  'Nov',
  'Dic',
];

/// Grafico "andamento nel tempo" (richiesta esplicita dell'utente: "vorrei
/// vedere l'andamento delle mie spese negli ultimi mesi"): entrate/uscite
/// confermate degli ultimi 6 mesi, una coppia di barre per mese — stessa
/// coppia di colori del grafico a torta sopra, per coerenza visiva.
class _TrendChart extends StatefulWidget {
  const _TrendChart({required this.trend});

  final List<MonthlyTotals> trend;

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  // Le barre partono da altezza zero e crescono fino al valore reale al
  // primo caricamento (richiesta esplicita dell'utente: "animazione
  // d'ingresso sui grafici") — stessa tecnica di _CategoryTrendChart.
  bool _grown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _grown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final trend = widget.trend;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final incomeColor = AppColors.heroGradient[0];
    final expenseColor = AppColors.heroGradient[1];

    final maxValue = trend.fold<int>(
        0,
        (max, m) => [max, m.incomeCents, m.expenseCents]
            .reduce((a, b) => a > b ? a : b));

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.standardRadius,
        boxShadow: AppShadows.glow(color: incomeColor, isDark: isDark),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Andamento ultimi 6 mesi', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 180,
                child: maxValue == 0
                    ? const Center(
                        child: Text(
                            'Nessun importo confermato in questo periodo.'),
                      )
                    : BarChart(
                        swapAnimationDuration:
                            const Duration(milliseconds: 600),
                        swapAnimationCurve: Curves.easeOutCubic,
                        BarChartData(
                          maxY: maxValue * 1.2,
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index < 0 || index >= trend.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final month = trend[index].month;
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        top: AppSpacing.xs),
                                    child: Text(
                                      _italianMonthsShort[month.month - 1],
                                      style: AppTypography.caption,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: [
                            for (var i = 0; i < trend.length; i++)
                              BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: _grown
                                        ? trend[i].incomeCents.toDouble()
                                        : 0,
                                    color: incomeColor,
                                    width: 8,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  BarChartRodData(
                                    toY: _grown
                                        ? trend[i].expenseCents.toDouble()
                                        : 0,
                                    color: expenseColor,
                                    width: 8,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                                barsSpace: 4,
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _TrendLegendDot(color: incomeColor, label: 'Entrate'),
                  const SizedBox(width: AppSpacing.md),
                  _TrendLegendDot(color: expenseColor, label: 'Uscite'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _heatmapWeekdays = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

/// Heatmap delle spese del mese (integrazione richiesta esplicitamente):
/// un calendario a quadratini colorati in base all'intensità di spesa di
/// quel giorno — stesso linguaggio visivo di `MonthCalendarGrid`
/// (`Color.alphaBlend` su `AppColors.error`), qui con un'intensità continua
/// invece di un semplice on/off. Puramente visiva, nessun tocco/interazione:
/// con altre due migliorie da consegnare in questo stesso giro, lo scope è
/// stato volutamente limitato a un colpo d'occhio d'insieme — il dettaglio
/// giorno per giorno resta comunque disponibile nell'elenco delle
/// Transazioni confermate più sotto.
class _ExpenseHeatmap extends StatelessWidget {
  const _ExpenseHeatmap({required this.month, required this.dailyTotals});

  final DateTime month;
  final Map<int, int> dailyTotals;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxCents =
        dailyTotals.values.fold<int>(0, (max, v) => v > max ? v : max);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // weekday: 1 (lunedì) .. 7 (domenica) — stessa convenzione di
    // MonthCalendarGrid, la settimana parte sempre di lunedì.
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    const accent = AppColors.error;

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.standardRadius,
        boxShadow: AppShadows.glow(color: accent, isDark: isDark),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Intensità di spesa', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.md),
              if (maxCents == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('Nessuna spesa confermata in questo mese.'),
                )
              else ...[
                Row(
                  children: [
                    for (final label in _heatmapWeekdays)
                      Expanded(
                        child: Center(
                          child: Text(
                            label,
                            style: AppTypography.caption.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                // Dissolvenza in ingresso al primo caricamento (richiesta
                // esplicita dell'utente: "animazione d'ingresso sui
                // grafici") — `TweenAnimationBuilder` anima da sola dal
                // valore iniziale a quello finale non appena il widget
                // compare, senza bisogno di un AnimationController esplicito.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder: (context, opacity, child) => Opacity(
                    opacity: opacity,
                    child: child,
                  ),
                  child: GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 0; i < leadingBlanks; i++)
                        const SizedBox.shrink(),
                      for (var day = 1; day <= daysInMonth; day++)
                        _HeatmapDayCell(
                          day: day,
                          intensity: (dailyTotals[day] ?? 0) / maxCents,
                          color: accent,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeatmapDayCell extends StatelessWidget {
  const _HeatmapDayCell({
    required this.day,
    required this.intensity,
    required this.color,
  });

  final int day;
  final double intensity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSpend = intensity > 0;
    // Intensità minima visibile (0.12) anche per una spesa piccola rispetto
    // al giorno più caro del mese: altrimenti sembrerebbe un giorno "vuoto"
    // pur avendo almeno una transazione.
    final fillColor = hasSpend
        ? Color.alphaBlend(
            color.withOpacity(0.12 + intensity * 0.68),
            theme.colorScheme.surface,
          )
        : Colors.transparent;
    final numberColor = hasSpend && intensity > 0.4
        ? Colors.white
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '$day',
            style: AppTypography.caption.copyWith(color: numberColor),
          ),
        ),
      ),
    );
  }
}

class _TrendLegendDot extends StatelessWidget {
  const _TrendLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}

class _PendingTransactionTile extends ConsumerWidget {
  const _PendingTransactionTile(
      {required this.transaction, required this.workspaceName});

  final Transaction transaction;
  final String workspaceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: Text(
          transaction.type == TransactionType.income ? '💰' : '💸',
          style: const TextStyle(fontSize: 22),
        ),
        title: Text(transaction.description,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$workspaceName · ${_formatDate(transaction.occurredAt)} · '
              '${_formatAmount(transaction.amountCents)} · ',
            ),
            _CategoryBadge(category: transaction.category),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Conferma',
              onPressed: () => ref
                  .read(transactionFormControllerProvider.notifier)
                  .confirm(transaction.id),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Scarta',
              onPressed: () => ref
                  .read(transactionFormControllerProvider.notifier)
                  .delete(transaction.id),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transazione confermata come "pillola" sopraelevata (richiesta esplicita
/// dell'utente: "transazioni confermate racchiuse in pillola, sopraelevate")
/// — angoli molto arrotondati + ombra, non la Card piatta di prima (elevation
/// 0 nel tema globale).
class _ConfirmedTransactionTile extends StatelessWidget {
  const _ConfirmedTransactionTile(
      {required this.transaction, required this.workspaceName});

  final Transaction transaction;
  final String workspaceName;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadii.cardPremiumRadius,
        boxShadow: AppShadows.card(isDark: theme.brightness == Brightness.dark),
      ),
      child: Row(
        children: [
          Text(isIncome ? '💰' : '💸', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  transaction.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        '$workspaceName · ${_formatDate(transaction.occurredAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _CategoryBadge(category: transaction.category),
                  ],
                ),
                if (transaction.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final tag in transaction.tags)
                        _TransactionTagPill(label: tag),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _formatAmount(transaction.amountCents),
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Pillola compatta per un tag di Transazione — solo lettura (stesso ruolo di
/// `_TagPill` in `note_list_screen.dart`, qui col colore del Bilancio invece
/// di quello delle Note).
class _TransactionTagPill extends StatelessWidget {
  const _TransactionTagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.categoryBilancio.withOpacity(0.14),
        borderRadius: AppRadii.buttonRadius,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.categoryBilancio,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Pillola colorata (icona + etichetta) di una categoria — redesign estetico
/// 2.0: prima solo un'icona colorata su testo semplice, ora un rilievo
/// leggero coerente con le altre superfici "chip" della app (sezioni in
/// Chat), riusata ovunque il Bilancio elenca una transazione.
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final TransactionCategory category;

  @override
  Widget build(BuildContext context) {
    final meta = TransactionCategoryMeta.of(category);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: meta.color.withOpacity(0.14),
        borderRadius: AppRadii.buttonRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 13, color: meta.color),
          const SizedBox(width: 2),
          Text(
            meta.label,
            style: AppTypography.caption
                .copyWith(color: meta.color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String _formatAmount(int amountCents) =>
    '${(amountCents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

String _formatSignedAmount(int amountCents) {
  final sign = amountCents > 0 ? '+' : (amountCents < 0 ? '-' : '');
  return '$sign${_formatAmount(amountCents.abs())}';
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Foglio "Condividi riepilogo" (richiesta esplicita dell'utente: un export
/// mensile del Bilancio). Niente PDF: `pdf`/`printing`/`share_plus` sono
/// pacchetti pub.dev che in questo ambiente di build non è stato possibile
/// aggiungere e verificare — un riepilogo testuale con copia negli appunti e
/// invio via email (`url_launcher`, già una dipendenza del progetto) copre
/// lo stesso bisogno senza introdurre dipendenze nuove.
void _showExportSheet(
  BuildContext context, {
  required DateTime month,
  required int balanceCents,
  required int incomeCents,
  required int expenseCents,
  required Map<TransactionCategory, int> incomeByCategory,
  required Map<TransactionCategory, int> expenseByCategory,
}) {
  final summary = _buildSummaryText(
    month: month,
    balanceCents: balanceCents,
    incomeCents: incomeCents,
    expenseCents: expenseCents,
    incomeByCategory: incomeByCategory,
    expenseByCategory: expenseByCategory,
  );

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Riepilogo ${_italianMonths[month.month - 1]} ${month.year}',
                style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.05),
                    borderRadius: AppRadii.standardRadius,
                  ),
                  child: Text(summary, style: AppTypography.caption),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: summary));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Riepilogo copiato negli appunti.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copia negli appunti'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () =>
                  _sendSummaryByEmail(context, month: month, body: summary),
              icon: const Icon(Icons.email_outlined),
              label: const Text('Invia via email'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _sendSummaryByEmail(
  BuildContext context, {
  required DateTime month,
  required String body,
}) async {
  final subject =
      'Riepilogo Bilancio ${_italianMonths[month.month - 1]} ${month.year}';
  final uri = Uri(
    scheme: 'mailto',
    query:
        'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
  );
  final launched = await launchUrl(uri);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Non è stato possibile aprire un\'app email.')),
    );
  }
}

String _buildSummaryText({
  required DateTime month,
  required int balanceCents,
  required int incomeCents,
  required int expenseCents,
  required Map<TransactionCategory, int> incomeByCategory,
  required Map<TransactionCategory, int> expenseByCategory,
}) {
  final buffer = StringBuffer()
    ..writeln(
        'Riepilogo Bilancio — ${_italianMonths[month.month - 1]} ${month.year}')
    ..writeln()
    ..writeln('Saldo: ${_formatSignedAmount(balanceCents)}')
    ..writeln('Entrate: ${_formatAmount(incomeCents)}')
    ..writeln('Uscite: ${_formatAmount(expenseCents)}');

  void writeCategoryLines(
      String title, Map<TransactionCategory, int> byCategory) {
    if (byCategory.isEmpty) return;
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    buffer
      ..writeln()
      ..writeln('$title per categoria:');
    for (final entry in entries) {
      final meta = TransactionCategoryMeta.of(entry.key);
      buffer.writeln('- ${meta.label}: ${_formatAmount(entry.value)}');
    }
  }

  writeCategoryLines('Entrate', incomeByCategory);
  writeCategoryLines('Uscite', expenseByCategory);

  return buffer.toString();
}

/// Budget per categoria (richiesta esplicita dell'utente: "budget per
/// categoria"), legato all'utente — non a un Workspace — e valutato contro
/// [expenseByCategory], lo stesso aggregato multi-Workspace già mostrato dal
/// resto della schermata (esclusi i Bilanci condivisi). Nascosto del tutto
/// se non c'è alcun budget impostato: non è un placeholder, è una feature
/// opzionale che l'utente attiva categoria per categoria.
class _BudgetSection extends ConsumerWidget {
  const _BudgetSection({required this.expenseByCategory});

  final Map<TransactionCategory, int> expenseByCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);

    return budgetsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (budgets) {
        if (budgets.isEmpty) {
          return Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showSetBudgetDialog(context, ref),
              icon: const Icon(Icons.speed_outlined),
              label: const Text('Imposta un budget per categoria'),
            ),
          );
        }

        final sorted = budgets.toList()
          ..sort((a, b) => TransactionCategoryMeta.of(a.category)
              .label
              .compareTo(TransactionCategoryMeta.of(b.category).label));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Budget per categoria', style: AppTypography.heading3),
                TextButton(
                  onPressed: () => _showSetBudgetDialog(context, ref),
                  child: const Text('Aggiungi'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final budget in sorted) ...[
              _BudgetTile(
                budget: budget,
                spentCents: expenseByCategory[budget.category] ?? 0,
                onTap: () => _showSetBudgetDialog(context, ref, budget: budget),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showSetBudgetDialog(
    BuildContext context,
    WidgetRef ref, {
    CategoryBudget? budget,
  }) async {
    final budgetsAsync = ref.read(budgetsProvider).value ?? const [];
    final alreadyBudgeted = budgetsAsync.map((b) => b.category).toSet();

    final result = await showDialog<_BudgetDialogResult>(
      context: context,
      builder: (context) => _SetBudgetDialog(
        initial: budget,
        // Nella creazione (non nella modifica) non si può scegliere una
        // categoria già budgetata: setBudget farebbe comunque un upsert, ma
        // mostrerebbe due righe per la stessa categoria fino al refresh.
        excludedCategories: budget == null ? alreadyBudgeted : const {},
      ),
    );
    if (result == null) return;
    if (!context.mounted) return;

    if (result.delete && budget != null) {
      final failure = await ref
          .read(budgetFormControllerProvider.notifier)
          .deleteBudget(budget.id);
      if (!context.mounted) return;
      if (failure != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      }
      return;
    }

    final failure =
        await ref.read(budgetFormControllerProvider.notifier).setBudget(
              category: result.category!,
              monthlyLimitCents: result.monthlyLimitCents!,
            );
    if (!context.mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.budget,
    required this.spentCents,
    required this.onTap,
  });

  final CategoryBudget budget;
  final int spentCents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = TransactionCategoryMeta.of(budget.category);
    final ratio = budget.monthlyLimitCents == 0
        ? 0.0
        : spentCents / budget.monthlyLimitCents;
    final isOverBudget = spentCents > budget.monthlyLimitCents;
    final barColor = isOverBudget ? AppColors.error : meta.color;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.standardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ColorfulIconBadge(
                    icon: meta.icon,
                    color: meta.color,
                    size: 30,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(meta.label, style: AppTypography.body),
                  ),
                  Text(
                    '${_formatAmount(spentCents)} / ${_formatAmount(budget.monthlyLimitCents)}',
                    style: AppTypography.caption.copyWith(
                      color: isOverBudget
                          ? AppColors.error
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                      fontWeight:
                          isOverBudget ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: barColor.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
              if (isOverBudget) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Budget superato',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.error, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetDialogResult {
  const _BudgetDialogResult.set(this.category, this.monthlyLimitCents)
      : delete = false;
  const _BudgetDialogResult.delete()
      : category = null,
        monthlyLimitCents = null,
        delete = true;

  final TransactionCategory? category;
  final int? monthlyLimitCents;
  final bool delete;
}

/// Dialog per creare/modificare/cancellare un budget — `StatefulWidget`
/// dedicato (stesso motivo di `_AddMemoryDialog`: il `TextEditingController`
/// deve restare vivo per tutta l'animazione di chiusura del dialog).
class _SetBudgetDialog extends StatefulWidget {
  const _SetBudgetDialog({this.initial, required this.excludedCategories});

  final CategoryBudget? initial;
  final Set<TransactionCategory> excludedCategories;

  @override
  State<_SetBudgetDialog> createState() => _SetBudgetDialogState();
}

class _SetBudgetDialogState extends State<_SetBudgetDialog> {
  late TransactionCategory _category = widget.initial?.category ??
      TransactionCategory.values.firstWhere(
          (c) => !widget.excludedCategories.contains(c),
          orElse: () => TransactionCategory.altro);
  late final _amountController = TextEditingController(
    text: widget.initial == null
        ? ''
        : (widget.initial!.monthlyLimitCents / 100).toStringAsFixed(2),
  );

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectableCategories = TransactionCategory.values
        .where((c) => c == _category || !widget.excludedCategories.contains(c))
        .toList(growable: false);

    return AlertDialog(
      title: Text(widget.initial == null ? 'Nuovo budget' : 'Modifica budget'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<TransactionCategory>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [
              for (final category in selectableCategories)
                DropdownMenuItem(
                  value: category,
                  child: Text(TransactionCategoryMeta.of(category).label),
                ),
            ],
            onChanged: widget.initial != null
                ? null
                : (value) => setState(() => _category = value!),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Budget mensile',
              prefixText: '€ ',
            ),
          ),
        ],
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _BudgetDialogResult.delete()),
            child: const Text('Elimina'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            final amount =
                double.tryParse(_amountController.text.replaceAll(',', '.'));
            if (amount == null || amount <= 0) return;
            Navigator.of(context).pop(
              _BudgetDialogResult.set(_category, (amount * 100).round()),
            );
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}
