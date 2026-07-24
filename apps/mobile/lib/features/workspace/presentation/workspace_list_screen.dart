import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/skeleton_list.dart';
import '../../auth/application/session_controller.dart';
import '../../chat/application/chat_controller.dart';
import '../../chat/application/message_controller.dart';
import '../../reminder/application/calendar_event_controller.dart';
import '../../task/application/task_controller.dart';
import '../../transaction/application/transaction_controller.dart';
import '../application/workspace_controller.dart';
import 'create_workspace_sheet.dart';
import 'widgets/workspace_card.dart';

/// Home di Workspace (docs/product/06-information-architecture.md, "Workspace"
/// — "il cuore dell'app").
class WorkspaceListScreen extends ConsumerWidget {
  const WorkspaceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspacesAsync = ref.watch(workspacesProvider);

    return Scaffold(
      // Titolo "Spazi" (rinominato da "Workspace" — richiesta esplicita
      // dell'utente): il modello di dominio/le route restano "Workspace",
      // solo l'etichetta mostrata cambia.
      appBar: const GradientAppBar(title: Text('Spazi')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateWorkspaceSheet(context),
        child: const Icon(Icons.add),
      ),
      body: workspacesAsync.when(
        loading: () => const SkeletonList(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare i tuoi Workspace.',
          onRetry: () => ref.invalidate(workspacesProvider),
        ),
        data: (workspaces) {
          if (workspaces.isEmpty) {
            return EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'Nessun Workspace ancora',
              message:
                  'Crea il tuo primo Workspace per organizzare chat, documenti e attività.',
              action: FilledButton(
                onPressed: () => showCreateWorkspaceSheet(context),
                child: const Text('Crea il primo Workspace'),
              ),
            );
          }

          final now = DateTime.now();
          final user = ref.watch(sessionControllerProvider).asData?.value;
          final events =
              ref.watch(calendarEventsProvider(null)).asData?.value ??
                  const <CalendarEvent>[];
          final transactions =
              ref.watch(transactionsProvider(null)).asData?.value ??
                  const <Transaction>[];
          final chats = ref.watch(chatsProvider(null)).asData?.value ??
              const <Chat>[];

          var openTasksCount = 0;
          String? activitiesWorkspaceId;
          for (final workspace in workspaces) {
            final tasks = ref.watch(tasksProvider(workspace.id)).asData?.value ??
                const <Task>[];
            openTasksCount += openTasks(tasks).length;
            if (workspace.category == SystemWorkspaceCategory.attivita) {
              activitiesWorkspaceId = workspace.id;
            }
          }

          final todayEvents = events
              .where((event) =>
                  event.startsAt.year == now.year &&
                  event.startsAt.month == now.month &&
                  event.startsAt.day == now.day)
              .toList(growable: false)
            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
          final upcomingEvents = events
              .where((event) => event.startsAt.isAfter(now))
              .toList(growable: false)
            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
          final confirmed = confirmedThisMonth(transactions, now: now);

          final chat = chats.isEmpty ? null : chats.first;
          final messages = chat == null
              ? const <Message>[]
              : ref.watch(messagesProvider(chat.id)).asData?.value ??
                  const <Message>[];
          final assistantMessages = messages
              .where((message) =>
                  message.role == MessageRole.ai && message.content.trim().isNotEmpty)
              .toList(growable: false)
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: workspaces.length + 2,
            separatorBuilder: (_, index) => SizedBox(
              height: index == 0 ? AppSpacing.lg : AppSpacing.sm,
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _DayOverview(
                  userName: user?.name,
                  appointmentsToday: todayEvents.length,
                  openTasksCount: openTasksCount,
                  monthBalanceCents: balanceCents(confirmed),
                  lastAssistantMessage: assistantMessages.isEmpty
                      ? null
                      : assistantMessages.first.content,
                  nextReminder:
                      upcomingEvents.isEmpty ? null : upcomingEvents.first,
                  activitiesWorkspaceId: activitiesWorkspaceId,
                  spacesCount: workspaces.length,
                  onCreate: () => showCreateWorkspaceSheet(context),
                );
              }
              if (index == 1) {
                return Text('I tuoi spazi', style: AppTypography.heading3);
              }

              final workspace = workspaces[index - 2];
              return WorkspaceCard(
                workspace: workspace,
                // La sezione Appuntamenti apre direttamente il calendario
                // (richiesta esplicita dell'utente: "vorrei vedere il
                // calendario"), non l'anteprima generica del Workspace —
                // da lì il calendario era raggiungibile solo con un tocco
                // in più su "vedi tutti".
                onTap: () => context.push(
                  workspace.category == SystemWorkspaceCategory.appuntamenti
                      ? '/workspace/${workspace.id}/reminders'
                      : '/workspace/${workspace.id}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Riepilogo della giornata richiesto dall'utente: rende "Spazi" una
/// dashboard utile prima dell'elenco delle sezioni, lasciando intatte le
/// emoji native colorate già presenti nell'app.
class _DayOverview extends StatelessWidget {
  const _DayOverview({
    required this.userName,
    required this.appointmentsToday,
    required this.openTasksCount,
    required this.monthBalanceCents,
    required this.lastAssistantMessage,
    required this.nextReminder,
    required this.activitiesWorkspaceId,
    required this.spacesCount,
    required this.onCreate,
  });

  final String? userName;
  final int appointmentsToday;
  final int openTasksCount;
  final int monthBalanceCents;
  final String? lastAssistantMessage;
  final CalendarEvent? nextReminder;
  final String? activitiesWorkspaceId;
  final int spacesCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
          Row(
            children: [
              Expanded(
                child: Text(
                  _greeting(userName),
                  style: AppTypography.heading2.copyWith(color: Colors.white),
                ),
              ),
              Text(
                '$spacesCount ${spacesCount == 1 ? 'spazio' : 'spazi'}',
                style: AppTypography.caption.copyWith(
                  color: Colors.white.withOpacity(0.82),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Ecco cosa sta succedendo oggi.',
            style: AppTypography.body.copyWith(
              color: Colors.white.withOpacity(0.86),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _OverviewRow(
            emoji: '📅',
            title: appointmentsToday == 0
                ? 'Nessun appuntamento oggi'
                : appointmentsToday == 1
                    ? '1 appuntamento oggi'
                    : '$appointmentsToday appuntamenti oggi',
            onTap: () => context.go('/appuntamenti'),
          ),
          _OverviewRow(
            emoji: '✅',
            title: openTasksCount == 0
                ? 'Tutte le attività completate'
                : openTasksCount == 1
                    ? '1 attività da completare'
                    : '$openTasksCount attività da completare',
            onTap: activitiesWorkspaceId == null
                ? null
                : () => context.push('/workspace/$activitiesWorkspaceId/tasks'),
          ),
          _OverviewRow(
            emoji: '💶',
            title: 'Saldo del mese: ${_formatAmount(monthBalanceCents)}',
            onTap: () => context.go('/balance'),
          ),
          _OverviewRow(
            emoji: '🔥',
            title: lastAssistantMessage == null
                ? 'L’assistente è pronto ad aiutarti'
                : _lastAssistantLabel(lastAssistantMessage!),
            onTap: () => context.go('/chat'),
          ),
          _OverviewRow(
            emoji: '⏰',
            title: nextReminder == null
                ? 'Nessun promemoria in arrivo'
                : 'Prossimo: ${nextReminder!.title} alle '
                    '${_formatTime(nextReminder!.startsAt)}',
            onTap: () => context.go('/appuntamenti'),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuovo spazio'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.65)),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final moment = hour < 12
        ? 'Buongiorno'
        : hour < 18
            ? 'Buon pomeriggio'
            : 'Buonasera';
    if (name == null || name.trim().isEmpty) return '$moment 👋';
    return '$moment, ${name.trim()} 👋';
  }

  String _formatAmount(int cents) {
    final sign = cents > 0 ? '+' : '';
    return '$sign${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _lastAssistantLabel(String message) {
    final compact = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    final preview = compact.length > 58
        ? '${compact.substring(0, 58).trimRight()}…'
        : compact;
    return 'Assistente: $preview';
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.emoji,
    required this.title,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: Colors.white.withOpacity(0.14),
        borderRadius: AppRadii.buttonRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.buttonRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 19)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
