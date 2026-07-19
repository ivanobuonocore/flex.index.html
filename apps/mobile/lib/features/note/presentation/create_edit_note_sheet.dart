import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../application/note_controller.dart';

/// Creazione o modifica di una nota (docs/product/06-information-architecture.md,
/// "Pulsante +" — qui applicato nel contesto già noto del Workspace/Note).
Future<void> showCreateEditNoteSheet(
  BuildContext context, {
  required String workspaceId,
  Note? note,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadii.cardPremium)),
    ),
    builder: (context) =>
        _CreateEditNoteSheet(workspaceId: workspaceId, note: note),
  );
}

class _CreateEditNoteSheet extends ConsumerStatefulWidget {
  const _CreateEditNoteSheet({required this.workspaceId, this.note});

  final String workspaceId;
  final Note? note;

  @override
  ConsumerState<_CreateEditNoteSheet> createState() =>
      _CreateEditNoteSheetState();
}

class _CreateEditNoteSheetState extends ConsumerState<_CreateEditNoteSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.note?.title);
  late final _contentController =
      TextEditingController(text: widget.note?.content);
  String? _errorMessage;

  bool get _isEditing => widget.note != null;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    final controller = ref.read(noteFormControllerProvider.notifier);
    final failure = _isEditing
        ? await controller.updateNote(
            widget.note!.copyWith(
              title: _titleController.text,
              content: _contentController.text,
              updatedAt: DateTime.now(),
            ),
          )
        : await controller.create(
            workspaceId: widget.workspaceId,
            title: _titleController.text,
            content: _contentController.text,
          );

    if (!mounted) return;
    if (failure != null) {
      setState(() => _errorMessage = failure.message);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(noteFormControllerProvider).isLoading;

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
            Text(
              _isEditing ? 'Modifica nota' : 'Nuova nota',
              style: AppTypography.heading2,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _titleController,
              autofocus: !_isEditing,
              decoration: const InputDecoration(labelText: 'Titolo'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Il titolo è obbligatorio'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: 'Contenuto'),
              maxLines: 5,
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
                  : Text(_isEditing ? 'Salva' : 'Crea nota'),
            ),
          ],
        ),
      ),
    );
  }
}
