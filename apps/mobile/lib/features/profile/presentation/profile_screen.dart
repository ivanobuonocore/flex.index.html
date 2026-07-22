import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../core/env/app_env.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/session_controller.dart';
import '../../export/presentation/data_export_sheet.dart';
import '../../notifications/application/push_notification_controller.dart';
import '../../notifications/data/push_notification_service.dart';
import '../../reminder/application/calendar_sync_controller.dart';

/// Profilo (docs/product/06-information-architecture.md, "Profilo"). In Fase
/// 1: identità dell'account, logout, preferenza di tema e Memoria.
/// Abbonamento e privacy arrivano con le rispettive feature (Fase 2+).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).value;
    final isSigningOut = ref.watch(authControllerProvider).isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Text(
                    _initials(user?.name),
                    style: AppTypography.heading3
                        .copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '—', style: AppTypography.heading3),
                      Text(user?.email ?? '', style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Piano'),
                trailing: Text(_planLabel(user?.plan)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ThemeModeCard(current: user?.themeMode ?? AppThemeMode.system),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: ListTile(
                leading: const Icon(Icons.psychology_outlined),
                title: const Text('Memoria'),
                subtitle: const Text(
                    'Cosa l\'assistente ricorda di te, tra una conversazione '
                    'e l\'altra.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/profile/memories'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Esporta i miei dati'),
                subtitle: const Text(
                    'Note, Attività, Documenti, Promemoria, Transazioni e '
                    'Memoria in un file JSON.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDataExportSheet(context, ref),
              ),
            ),
            if (AppEnv.vapidPublicKey.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const _NotificationsCard(),
            ],
            if (AppEnv.googleCalendarEnabled) ...[
              const SizedBox(height: AppSpacing.lg),
              const _GoogleCalendarCard(),
            ],
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: isSigningOut
                  ? null
                  : () => ref.read(authControllerProvider.notifier).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Esci'),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return (first + last).toUpperCase();
  }

  String _planLabel(UserPlan? plan) {
    switch (plan) {
      case UserPlan.pro:
        return 'Pro';
      case UserPlan.business:
        return 'Business';
      case UserPlan.free:
      case null:
        return 'Free';
    }
  }
}

/// Preferenza di tema (richiesta esplicita dell'utente: "tema chiaro/scuro"),
/// persistita nei metadata dell'identity provider (vedi
/// [AuthRepository.updateThemeMode]) — nessuna nuova tabella, è una
/// preferenza globale all'utente, non a un Workspace.
class _ThemeModeCard extends ConsumerWidget {
  const _ThemeModeCard({required this.current});

  final AppThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBusy = ref.watch(authControllerProvider).isLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dark_mode_outlined),
                const SizedBox(width: AppSpacing.sm),
                Text('Tema', style: AppTypography.heading3),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.system,
                  label: Text('Sistema'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: AppThemeMode.light,
                  label: Text('Chiaro'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  label: Text('Scuro'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {current},
              onSelectionChanged: isBusy
                  ? null
                  : (selection) =>
                      ref.read(authControllerProvider.notifier).updateThemeMode(
                            selection.first,
                          ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prima slice delle notifiche push vere (CLAUDE.md — "infrastruttura + prova"):
/// solo attivazione e un pulsante di prova, non ancora i Promemoria veri.
/// Nascosta del tutto se l'app non è stata compilata con una chiave VAPID
/// (vedi [AppEnv.vapidPublicKey]) — l'app resta utilizzabile anche senza.
class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(pushSupportStatusProvider);
    final isBusy = ref.watch(pushNotificationControllerProvider).isLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_outlined),
                const SizedBox(width: AppSpacing.sm),
                Text('Notifiche', style: AppTypography.heading3),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            statusAsync.when(
              data: (status) => _statusContent(context, ref, status, isBusy),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, __) => Text(
                'Non è stato possibile verificare lo stato delle notifiche.',
                style: AppTypography.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusContent(
    BuildContext context,
    WidgetRef ref,
    PushSupportStatus status,
    bool isBusy,
  ) {
    switch (status) {
      case PushSupportStatus.unsupported:
        return Text(
          'Le notifiche non sono supportate su questo dispositivo o browser. '
          'Su iPhone funzionano solo dopo aver aggiunto il sito alla schermata '
          'Home (icona Condividi → Aggiungi a Home).',
          style: AppTypography.caption,
        );
      case PushSupportStatus.notSubscribed:
        return ElevatedButton.icon(
          onPressed: isBusy ? null : () => _activate(context, ref),
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Attiva notifiche'),
        );
      case PushSupportStatus.subscribed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notifiche attive su questo dispositivo.',
                style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: isBusy ? null : () => _sendTest(context, ref),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Invia una notifica di prova'),
            ),
          ],
        );
    }
  }

  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    final failure = await ref
        .read(pushNotificationControllerProvider.notifier)
        .subscribe(AppEnv.vapidPublicKey);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure?.message ?? 'Notifiche attivate.'),
      ),
    );
  }

  Future<void> _sendTest(BuildContext context, WidgetRef ref) async {
    final failure = await ref
        .read(pushNotificationControllerProvider.notifier)
        .sendTestNotification();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure?.message ?? 'Notifica di prova inviata.'),
      ),
    );
  }
}

/// Sync con Google Calendar (integrazione richiesta esplicitamente). Nascosta
/// del tutto se l'app non è stata compilata con
/// `--dart-define=GOOGLE_CALENDAR_ENABLED=true` (vedi [AppEnv.googleCalendarEnabled])
/// — richiede che il provider Google sia già abilitato nel dashboard Supabase,
/// stesso principio già usato per [_NotificationsCard]/VAPID.
class _GoogleCalendarCard extends ConsumerWidget {
  const _GoogleCalendarCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(calendarConnectionProvider);
    final isBusy = ref.watch(calendarSyncFormControllerProvider).isLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available_outlined),
                const SizedBox(width: AppSpacing.sm),
                Text('Google Calendar', style: AppTypography.heading3),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            connectionAsync.when(
              data: (connection) =>
                  _statusContent(context, ref, connection, isBusy),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, __) => Text(
                'Non è stato possibile verificare lo stato del collegamento.',
                style: AppTypography.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusContent(
    BuildContext context,
    WidgetRef ref,
    CalendarConnection? connection,
    bool isBusy,
  ) {
    if (connection == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Collega Google Calendar per far comparire lì i tuoi '
            'Appuntamenti creati in PIP.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton.icon(
            onPressed: isBusy ? null : () => _connect(context, ref),
            icon: const Icon(Icons.link),
            label: const Text('Connetti Google Calendar'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          connection.lastSyncedAt != null
              ? 'Connesso — ultima sincronizzazione ${_formatDateTime(connection.lastSyncedAt!)}.'
              : 'Connesso — prima sincronizzazione in corso.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: isBusy ? null : () => _disconnect(context, ref),
          icon: const Icon(Icons.link_off),
          label: const Text('Scollega'),
        ),
      ],
    );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    final failure =
        await ref.read(calendarSyncFormControllerProvider.notifier).connect();
    if (!context.mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }
    // Il collegamento vero e proprio si completa in modo asincrono, dopo il
    // redirect OAuth (vedi SupabaseCalendarSyncRepository) — nessun dato
    // nuovo da leggere subito qui.
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final failure = await ref
        .read(calendarSyncFormControllerProvider.notifier)
        .disconnect();
    if (!context.mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  String _formatDateTime(DateTime dateTime) =>
      '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')} '
      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}
