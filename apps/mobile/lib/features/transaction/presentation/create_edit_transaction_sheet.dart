import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../application/transaction_category_meta.dart';
import '../application/transaction_controller.dart';

/// Creazione o modifica manuale di una Transazione (entrata o uscita)
/// (docs/product/06-information-architecture.md, "Pulsante +"). Una
/// transazione creata da qui è sempre `confirmed` fin da subito: l'utente
/// l'ha scritta deliberatamente, a differenza di quelle suggerite dall'AI
/// Engine. Il tipo (entrata/uscita) non è modificabile in modifica: si
/// elimina e se ne crea una nuova, coerente con l'assenza di un campo `type`
/// in [TransactionRepository.updateTransaction].
Future<void> showCreateEditTransactionSheet(
  BuildContext context, {
  required String workspaceId,
  Transaction? transaction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadii.cardPremium)),
    ),
    builder: (context) => _CreateEditTransactionSheet(
        workspaceId: workspaceId, transaction: transaction),
  );
}

class _CreateEditTransactionSheet extends ConsumerStatefulWidget {
  const _CreateEditTransactionSheet(
      {required this.workspaceId, this.transaction});

  final String workspaceId;
  final Transaction? transaction;

  @override
  ConsumerState<_CreateEditTransactionSheet> createState() =>
      _CreateEditTransactionSheetState();
}

class _CreateEditTransactionSheetState
    extends ConsumerState<_CreateEditTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _descriptionController =
      TextEditingController(text: widget.transaction?.description);
  late final _amountController = TextEditingController(
    text: widget.transaction != null
        ? _formatAmountForInput(widget.transaction!.amountCents)
        : null,
  );
  late DateTime _occurredAt = widget.transaction?.occurredAt ?? DateTime.now();
  late TransactionType _type =
      widget.transaction?.type ?? TransactionType.expense;
  late TransactionCategory _category =
      widget.transaction?.category ?? TransactionCategory.altro;
  String? _errorMessage;

  bool get _isEditing => widget.transaction != null;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _occurredAt = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amountCents = _parseAmountToCents(_amountController.text);
    if (amountCents == null) return;

    setState(() => _errorMessage = null);

    final controller = ref.read(transactionFormControllerProvider.notifier);
    final failure = _isEditing
        ? await controller.updateTransaction(
            widget.transaction!.copyWith(
              description: _descriptionController.text,
              amountCents: amountCents,
              occurredAt: _occurredAt,
              category: _category,
            ),
          )
        : await controller.create(
            workspaceId: widget.workspaceId,
            type: _type,
            description: _descriptionController.text,
            amountCents: amountCents,
            occurredAt: _occurredAt,
            category: _category,
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
    final isLoading = ref.watch(transactionFormControllerProvider).isLoading;

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
              _isEditing ? 'Modifica transazione' : 'Nuova transazione',
              style: AppTypography.heading2,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!_isEditing) ...[
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Uscita'),
                    icon: Icon(Icons.remove_circle_outline),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Entrata'),
                    icon: Icon(Icons.add_circle_outline),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextFormField(
              controller: _descriptionController,
              autofocus: !_isEditing,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'La descrizione è obbligatoria'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Importo (€)'),
              validator: (value) => _parseAmountToCents(value ?? '') == null
                  ? 'Importo non valido'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data'),
              subtitle: Text(_formatDate(_occurredAt)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Categoria', style: AppTypography.caption),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: TransactionCategory.values.map((category) {
                final meta = TransactionCategoryMeta.of(category);
                return ChoiceChip(
                  avatar: Icon(meta.icon, size: 18, color: meta.color),
                  label: Text(meta.label),
                  selected: category == _category,
                  onSelected: (_) => setState(() => _category = category),
                );
              }).toList(growable: false),
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
                  : Text(_isEditing ? 'Salva' : 'Crea transazione'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accetta sia `,` sia `.` come separatore decimale (tastiera italiana vs
/// numerica); ritorna `null` se il testo non rappresenta un importo positivo.
int? _parseAmountToCents(String input) {
  final normalized = input.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final value = double.tryParse(normalized);
  if (value == null || value <= 0) return null;
  return (value * 100).round();
}

String _formatAmountForInput(int amountCents) =>
    (amountCents / 100).toStringAsFixed(2);

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
