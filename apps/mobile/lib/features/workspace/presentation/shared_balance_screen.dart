import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/application/session_controller.dart';
import '../application/workspace_sharing_controller.dart';

/// Bilancio condiviso (Fase 3, "Bilancio condiviso" — richiesta esplicita
/// dell'utente: condividere il Bilancio con un'altra persona, mantenendo
/// ciascuno il proprio Bilancio personale separato). Punto d'ingresso unico
/// per creare un Bilancio condiviso (mostra subito il codice da condividere)
/// o unirsi a uno esistente con un codice ricevuto — la gestione quotidiana
/// delle transazioni resta sul `WorkspaceDetailScreen`/`TransactionReportScreen`
/// già esistenti e generici per qualunque Workspace.
class SharedBalanceScreen extends ConsumerWidget {
  const SharedBalanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharedBalancesAsync = ref.watch(sharedBalancesProvider);
    final userId = ref.watch(sessionControllerProvider).value?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Bilancio condiviso')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Crea'),
      ),
      body: sharedBalancesAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare i Bilanci condivisi.',
          onRetry: () => ref.invalidate(sharedBalancesProvider),
        ),
        data: (workspaces) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Ho un codice d\'invito'),
                  subtitle: const Text(
                      'Unisciti al Bilancio condiviso di qualcun altro'),
                  onTap: () => _showRedeemSheet(context),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('I tuoi Bilanci condivisi', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.sm),
              if (workspaces.isEmpty)
                const EmptyState(
                  icon: Icons.people_outline,
                  title: 'Nessun Bilancio condiviso ancora',
                  message:
                      'Creane uno per condividere le spese con un\'altra persona, '
                      'oppure unisciti a uno con un codice d\'invito.',
                )
              else
                for (final workspace in workspaces)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Card(
                      child: ListTile(
                        leading:
                            const Icon(Icons.account_balance_wallet_outlined),
                        title: Text(workspace.name),
                        subtitle: Text(
                          workspace.ownerId == userId
                              ? 'Creato da te'
                              : 'Condiviso con te',
                        ),
                        trailing: workspace.ownerId == userId
                            ? IconButton(
                                icon: const Icon(Icons.group_outlined),
                                tooltip: 'Gestisci membri',
                                onPressed: () =>
                                    _showManageSheet(context, workspace),
                              )
                            : null,
                        onTap: () => context.push('/workspace/${workspace.id}'),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadii.cardPremium)),
      ),
      builder: (context) => const _CreateSharedBalanceSheet(),
    );
  }

  void _showRedeemSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadii.cardPremium)),
      ),
      builder: (context) => const _RedeemInviteSheet(),
    );
  }

  void _showManageSheet(BuildContext context, Workspace workspace) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadii.cardPremium)),
      ),
      builder: (context) => _ManageSharedBalanceSheet(workspace: workspace),
    );
  }
}

/// Crea un nuovo Bilancio condiviso (un Workspace libero, categoria
/// [sharedBalanceCategory]) e genera subito un codice d'invito da mostrare —
/// un solo passaggio invece di due, dato che creare un Bilancio condiviso
/// senza subito invitare qualcuno non avrebbe senso.
class _CreateSharedBalanceSheet extends ConsumerStatefulWidget {
  const _CreateSharedBalanceSheet();

  @override
  ConsumerState<_CreateSharedBalanceSheet> createState() =>
      _CreateSharedBalanceSheetState();
}

class _CreateSharedBalanceSheetState
    extends ConsumerState<_CreateSharedBalanceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Bilancio condiviso');
  String? _errorMessage;
  bool _isSubmitting = false;
  WorkspaceInvite? _createdInvite;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    // Chiama il repository direttamente, non `workspaceFormControllerProvider`
    // (che scarta il Workspace creato, ritornando solo l'eventuale errore):
    // serve subito l'id per generare l'invito, senza dover cercare a tentoni
    // il Workspace appena creato nello stream una volta arrivato.
    final workspaceResult =
        await ref.read(workspaceRepositoryProvider).createWorkspace(
              name: _nameController.text,
              icon: 'group',
              category: sharedBalanceCategory,
            );

    if (workspaceResult.isErr) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = (workspaceResult as Err<Workspace>).failure.message;
      });
      return;
    }

    final createdWorkspace = (workspaceResult as Ok<Workspace>).value;
    final inviteResult = await ref
        .read(workspaceSharingFormControllerProvider.notifier)
        .createInvite(createdWorkspace.id);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      inviteResult.fold(
        (invite) => _createdInvite = invite,
        (failure) => _errorMessage = failure.message,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final invite = _createdInvite;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: invite == null
          ? Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Nuovo Bilancio condiviso',
                      style: AppTypography.heading2),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Il nome è obbligatorio'
                            : null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_errorMessage!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Crea e genera un codice'),
                  ),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Bilancio condiviso creato!',
                    style: AppTypography.heading2),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Condividi questo codice con la persona con cui vuoi condividere '
                  'il Bilancio: potrà usarlo per unirsi e vedere/modificare anche '
                  'Note e Attività di questo Workspace (non i Documenti).',
                ),
                const SizedBox(height: AppSpacing.lg),
                _InviteCodeCard(code: invite.code),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fatto'),
                ),
              ],
            ),
    );
  }
}

class _RedeemInviteSheet extends ConsumerStatefulWidget {
  const _RedeemInviteSheet();

  @override
  ConsumerState<_RedeemInviteSheet> createState() => _RedeemInviteSheetState();
}

class _RedeemInviteSheetState extends ConsumerState<_RedeemInviteSheet> {
  final _codeController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    final result = await ref
        .read(workspaceSharingFormControllerProvider.notifier)
        .redeemInvite(_codeController.text);

    if (!mounted) return;
    result.fold(
      (workspace) => Navigator.of(context).pop(),
      (failure) => setState(() => _errorMessage = failure.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(workspaceSharingFormControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Unisciti a un Bilancio condiviso',
              style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _codeController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Codice d\'invito'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: isLoading ? null : _submit,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Unisciti'),
          ),
        ],
      ),
    );
  }
}

/// Solo per il proprietario: genera un nuovo codice d'invito e mostra/rimuove
/// i membri attuali.
class _ManageSharedBalanceSheet extends ConsumerStatefulWidget {
  const _ManageSharedBalanceSheet({required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<_ManageSharedBalanceSheet> createState() =>
      _ManageSharedBalanceSheetState();
}

class _ManageSharedBalanceSheetState
    extends ConsumerState<_ManageSharedBalanceSheet> {
  WorkspaceInvite? _newInvite;
  String? _errorMessage;

  Future<void> _createInvite() async {
    setState(() => _errorMessage = null);
    final result = await ref
        .read(workspaceSharingFormControllerProvider.notifier)
        .createInvite(widget.workspace.id);
    if (!mounted) return;
    result.fold(
      (invite) => setState(() => _newInvite = invite),
      (failure) => setState(() => _errorMessage = failure.message),
    );
  }

  Future<void> _removeMember(String userId) async {
    final failure = await ref
        .read(workspaceSharingFormControllerProvider.notifier)
        .removeMember(workspaceId: widget.workspace.id, userId: userId);
    if (!mounted) return;
    if (failure != null) setState(() => _errorMessage = failure.message);
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync =
        ref.watch(workspaceMembersProvider(widget.workspace.id));
    final isLoading =
        ref.watch(workspaceSharingFormControllerProvider).isLoading;
    final invite = _newInvite;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.workspace.name, style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.lg),
          Text('Membri', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.sm),
          membersAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) =>
                const Text('Non è stato possibile caricare i membri.'),
            data: (members) => members.isEmpty
                ? const Text(
                    'Nessun membro ancora: genera un codice e condividilo.')
                : Column(
                    children: members
                        .map((member) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person_outline),
                              title: Text(member.userId),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_remove_outlined),
                                tooltip: 'Rimuovi',
                                onPressed: () => _removeMember(member.userId),
                              ),
                            ))
                        .toList(growable: false),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (invite != null) ...[
            _InviteCodeCard(code: invite.code),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_errorMessage != null) ...[
            Text(_errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: AppSpacing.md),
          ],
          OutlinedButton.icon(
            onPressed: isLoading ? null : _createInvite,
            icon: const Icon(Icons.add_link),
            label: const Text('Genera un nuovo codice d\'invito'),
          ),
        ],
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                code,
                style: AppTypography.heading2.copyWith(letterSpacing: 4),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copia',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Codice copiato')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
