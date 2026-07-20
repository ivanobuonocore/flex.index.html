import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../application/workspace_controller.dart';

/// Rinomina/personalizza un Workspace esistente — anche una sezione fissa,
/// che resta però non eliminabile (vedi [WorkspaceCard]).
Future<void> showEditWorkspaceSheet(
  BuildContext context, {
  required Workspace workspace,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadii.cardPremium)),
    ),
    builder: (context) => _EditWorkspaceSheet(workspace: workspace),
  );
}

class _EditWorkspaceSheet extends ConsumerStatefulWidget {
  const _EditWorkspaceSheet({required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<_EditWorkspaceSheet> createState() =>
      _EditWorkspaceSheetState();
}

class _EditWorkspaceSheetState extends ConsumerState<_EditWorkspaceSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.workspace.name);
  late final _descriptionController =
      TextEditingController(text: widget.workspace.description ?? '');
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    // Costruito direttamente (non con copyWith): copyWith usa `??`, quindi
    // non permetterebbe di svuotare una descrizione già impostata.
    final updated = Workspace(
      id: widget.workspace.id,
      ownerId: widget.workspace.ownerId,
      name: _nameController.text.trim(),
      icon: widget.workspace.icon,
      status: widget.workspace.status,
      createdAt: widget.workspace.createdAt,
      category: widget.workspace.category,
      color: widget.workspace.color,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );
    final failure = await ref
        .read(workspaceFormControllerProvider.notifier)
        .updateWorkspace(updated);

    if (!mounted) return;
    if (failure != null) {
      setState(() => _errorMessage = failure.message);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(workspaceFormControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rinomina Workspace', style: AppTypography.heading2),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Il nome è obbligatorio'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              decoration:
                  const InputDecoration(labelText: 'Descrizione (facoltativa)'),
              maxLines: 2,
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
                  : const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }
}
