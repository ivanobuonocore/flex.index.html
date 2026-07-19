import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';

import '../application/chat_controller.dart';

/// Creazione di una nuova Chat dentro un Workspace (docs/product/06,
/// "Pulsante +"). A differenza di Note/Task/Documenti, alla creazione si
/// naviga subito al dettaglio: una Chat vuota in un elenco non è utile
/// quanto poterci scrivere subito.
Future<void> showCreateChatSheet(BuildContext context, {required String workspaceId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.cardPremium)),
    ),
    builder: (context) => _CreateChatSheet(workspaceId: workspaceId),
  );
}

class _CreateChatSheet extends ConsumerStatefulWidget {
  const _CreateChatSheet({required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<_CreateChatSheet> createState() => _CreateChatSheetState();
}

class _CreateChatSheetState extends ConsumerState<_CreateChatSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    final result = await ref
        .read(chatFormControllerProvider.notifier)
        .create(workspaceId: widget.workspaceId, title: _titleController.text);

    if (!mounted) return;
    result.fold(
      (chat) {
        Navigator.of(context).pop();
        context.push('/workspace/${widget.workspaceId}/chat/${chat.id}');
      },
      (failure) => setState(() => _errorMessage = failure.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(chatFormControllerProvider).isLoading;

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
            const Text('Nuova chat', style: AppTypography.heading2),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Titolo'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Il titolo è obbligatorio' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                  : const Text('Crea e apri'),
            ),
          ],
        ),
      ),
    );
  }
}
