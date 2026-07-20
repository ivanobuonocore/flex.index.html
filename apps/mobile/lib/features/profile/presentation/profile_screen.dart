import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../core/env/app_env.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/session_controller.dart';
import '../../notifications/application/push_notification_controller.dart';
import '../../notifications/data/push_notification_service.dart';

/// Profilo (docs/product/06-information-architecture.md, "Profilo"). In Fase
/// 1: identità dell'account e logout. Abbonamento, tema, memoria, privacy e
/// dispositivi arrivano con le rispettive feature (Fase 2+).
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
            if (AppEnv.vapidPublicKey.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const _NotificationsCard(),
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
            const Row(
              children: [
                Icon(Icons.notifications_outlined),
                SizedBox(width: AppSpacing.sm),
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
              error: (_, __) => const Text(
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
        return const Text(
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
            const Text('Notifiche attive su questo dispositivo.',
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
