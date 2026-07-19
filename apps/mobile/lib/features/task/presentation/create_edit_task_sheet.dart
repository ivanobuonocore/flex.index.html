import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../application/task_controller.dart';

/// Creazione o modifica di una task (docs/product/06-information-architecture.md,
/// "Pulsante +" — qui applicato nel contesto già noto del Workspace/Task).
Future<void> showCreateEditTaskSheet(
  BuildContext context, {
  required String workspaceId,
  Task? task,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadii.cardPremium)),
    ),
    builder: (context) =>
        _CreateEditTaskSheet(workspaceId: workspaceId, task: task),
  );
}

class _CreateEditTaskSheet extends ConsumerStatefulWidget {
  const _CreateEditTaskSheet({required this.workspaceId, this.task});

  final String workspaceId;
  final Task? task;

  @override
  ConsumerState<_CreateEditTaskSheet> createState() =>
      _CreateEditTaskSheetState();
}

class _CreateEditTaskSheetState extends ConsumerState<_CreateEditTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.task?.title);
  late final _descriptionController =
      TextEditingController(text: widget.task?.description);
  late TaskPriority _priority = widget.task?.priority ?? TaskPriority.medium;
  late DateTime? _dueAt = widget.task?.dueAt;
  String? _errorMessage;

  bool get _isEditing => widget.task != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _dueAt = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    final description = _descriptionController.text.trim();
    final controller = ref.read(taskFormControllerProvider.notifier);
    final failure = _isEditing
        ? await controller.updateTask(
            widget.task!.copyWith(
              title: _titleController.text,
              description: description.isEmpty ? null : description,
              priority: _priority,
              dueAt: _dueAt,
            ),
          )
        : await controller.create(
            workspaceId: widget.workspaceId,
            title: _titleController.text,
            description: description.isEmpty ? null : description,
            priority: _priority,
            dueAt: _dueAt,
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
    final isLoading = ref.watch(taskFormControllerProvider).isLoading;

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
              _isEditing ? 'Modifica task' : 'Nuova task',
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
              controller: _descriptionController,
              decoration:
                  const InputDecoration(labelText: 'Descrizione (facoltativa)'),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: TaskPriority.values.map((priority) {
                return ChoiceChip(
                  label: Text(_priorityLabel(priority)),
                  selected: priority == _priority,
                  onSelected: (_) => setState(() => _priority = priority),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _pickDueDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                  _dueAt == null ? 'Nessuna scadenza' : _formatDate(_dueAt!)),
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
                  : Text(_isEditing ? 'Salva' : 'Crea task'),
            ),
          ],
        ),
      ),
    );
  }

  String _priorityLabel(TaskPriority priority) => switch (priority) {
        TaskPriority.low => 'Bassa',
        TaskPriority.medium => 'Media',
        TaskPriority.high => 'Alta',
      };

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
