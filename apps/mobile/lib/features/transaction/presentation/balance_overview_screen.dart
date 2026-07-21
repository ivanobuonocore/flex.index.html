import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/loading_view.dart';
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
        loading: () => const LoadingView(),
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

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _MonthPicker(
                selectedMonth: selectedMonth,
                availableMonths: availableMonths,
                onChanged: (month) => setState(() => _selectedMonth = month),
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
              ),
              const SizedBox(height: AppSpacing.md),
              _BalancePieChart(incomeCents: income, expenseCents: expense),
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
              else
                for (final transaction in confirmed) ...[
                  _ConfirmedTransactionTile(
                    transaction: transaction,
                    workspaceName:
                        workspaceNames[transaction.workspaceId] ?? 'Workspace',
                  ),
                  const SizedBox(height: AppSpacing.xs),
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
  });

  final int balanceCents;
  final int incomeCents;
  final int expenseCents;

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
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _HeroStatPill(
                  emoji: '💰',
                  label: 'Entrate',
                  amountCents: incomeCents,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeroStatPill(
                  emoji: '💸',
                  label: 'Uscite',
                  amountCents: expenseCents,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pillola statistica dentro l'hero del saldo (Entrate/Uscite) — sfondo
/// bianco traslucido, non un colore semantico proprio: sul gradiente
/// heroGradient, il verde/rosso di AppColors.success/error perderebbe
/// leggibilità. Un'emoji al posto dell'icona +/- (richiesta esplicita
/// dell'utente: "non mi piacciono i segni + e - accanto a entrate e
/// uscite"): 💰/💸 comunicano lo stesso a colpo d'occhio senza sembrare un
/// segno matematico isolato.
class _HeroStatPill extends StatelessWidget {
  const _HeroStatPill({
    required this.emoji,
    required this.label,
    required this.amountCents,
  });

  final String emoji;
  final String label;
  final int amountCents;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: AppRadii.buttonRadius,
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
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
        ],
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
                          gradient: LinearGradient(
                            colors: [
                              slices[i].color,
                              Color.lerp(slices[i].color, Colors.white, 0.25)!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
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
                    color: Theme.of(context).colorScheme.surface,
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
