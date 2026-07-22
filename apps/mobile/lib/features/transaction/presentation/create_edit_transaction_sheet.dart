import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../document/application/document_controller.dart';
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
  final _tagInputController = TextEditingController();
  late List<String> _tags = List.of(widget.transaction?.tags ?? const []);
  String? _errorMessage;

  /// Stato locale (non letto da `widget.transaction`, che non si aggiorna da
  /// solo dopo l'attach/detach): riflette lo scontrino allegato per tutta la
  /// vita di questo foglio (richiesta esplicita dell'utente: "scontrino
  /// allegato alla Transazione").
  late String? _documentId = widget.transaction?.documentId;
  bool _isUpdatingReceipt = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  // Stesso pattern del form Nota (`create_edit_note_sheet.dart`): un tag per
  // invio/virgola, normalizzato in minuscolo.
  void _addTagFromInput() {
    final raw =
        _tagInputController.text.replaceAll(',', '').trim().toLowerCase();
    _tagInputController.clear();
    if (raw.isEmpty || _tags.contains(raw)) return;
    setState(() => _tags = [..._tags, raw]);
  }

  void _removeTag(String tag) {
    setState(() => _tags = _tags.where((t) => t != tag).toList());
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

  Future<void> _pickAndAttachReceipt() async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;

    setState(() => _isUpdatingReceipt = true);

    final uploadResult =
        await ref.read(documentFormControllerProvider.notifier).upload(
              workspaceId: widget.workspaceId,
              fileName: file.name,
              mimeType: _guessReceiptMimeType(file.extension),
              bytes: file.bytes!,
            );

    if (uploadResult.isErr) {
      if (!mounted) return;
      setState(() => _isUpdatingReceipt = false);
      final failure = (uploadResult as Err<Document>).failure;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }

    final document = (uploadResult as Ok<Document>).value;
    final attachFailure = await ref
        .read(transactionFormControllerProvider.notifier)
        .attachDocument(
            transactionId: widget.transaction!.id, documentId: document.id);

    if (!mounted) return;
    setState(() {
      _isUpdatingReceipt = false;
      if (attachFailure == null) _documentId = document.id;
    });
    if (attachFailure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(attachFailure.message)));
    }
  }

  Future<void> _removeReceipt() async {
    setState(() => _isUpdatingReceipt = true);
    final failure = await ref
        .read(transactionFormControllerProvider.notifier)
        .attachDocument(
            transactionId: widget.transaction!.id, documentId: null);

    if (!mounted) return;
    setState(() {
      _isUpdatingReceipt = false;
      if (failure == null) _documentId = null;
    });
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _openReceipt() async {
    final documentId = _documentId;
    if (documentId == null) return;
    try {
      final url =
          await ref.read(documentDownloadUrlProvider(documentId).future);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Non è stato possibile aprire lo scontrino.')));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amountCents = _parseAmountToCents(_amountController.text);
    if (amountCents == null) return;

    setState(() => _errorMessage = null);
    _addTagFromInput();

    final controller = ref.read(transactionFormControllerProvider.notifier);
    final failure = _isEditing
        ? await controller.updateTransaction(
            widget.transaction!.copyWith(
              description: _descriptionController.text,
              amountCents: amountCents,
              occurredAt: _occurredAt,
              category: _category,
              tags: _tags,
            ),
          )
        : await controller.create(
            workspaceId: widget.workspaceId,
            type: _type,
            description: _descriptionController.text,
            amountCents: amountCents,
            occurredAt: _occurredAt,
            category: _category,
            tags: _tags,
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
      // SingleChildScrollView (non solo Column): la riga "Scontrino" in più
      // (richiesta esplicita dell'utente) può superare l'altezza disponibile
      // su schermi piccoli o a tastiera aperta — senza scroll il contenuto in
      // eccesso resterebbe semplicemente tagliato, non solo "in teoria".
      child: SingleChildScrollView(
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
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _tagInputController,
                decoration: const InputDecoration(
                  labelText: 'Aggiungi un tag',
                  helperText: 'Invio o virgola per aggiungerlo',
                ),
                onFieldSubmitted: (_) => _addTagFromInput(),
                onChanged: (value) {
                  if (value.endsWith(',')) _addTagFromInput();
                },
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final tag in _tags)
                      Chip(
                        label: Text(tag),
                        onDeleted: () => _removeTag(tag),
                      ),
                  ],
                ),
              ],
              if (_isEditing) ...[
                const SizedBox(height: AppSpacing.md),
                _ReceiptAttachmentRow(
                  documentId: _documentId,
                  isBusy: _isUpdatingReceipt,
                  onAttach: _pickAndAttachReceipt,
                  onOpen: _openReceipt,
                  onRemove: _removeReceipt,
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_errorMessage!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
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

/// Solo i formati sensati per uno scontrino (foto o PDF) — a differenza di
/// `_guessMimeType` in `document_list_screen.dart`, non serve coprire office
/// docs qui, ed `allowedExtensions` sul file picker già li esclude.
String _guessReceiptMimeType(String? extension) {
  switch (extension?.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}

/// Riga "Scontrino" nel form di modifica di una Transazione (richiesta
/// esplicita dell'utente: "scontrino allegato alla Transazione") — nascosta
/// del tutto in creazione: serve l'id della Transazione già salvata per
/// collegare il Documento.
class _ReceiptAttachmentRow extends StatelessWidget {
  const _ReceiptAttachmentRow({
    required this.documentId,
    required this.isBusy,
    required this.onAttach,
    required this.onOpen,
    required this.onRemove,
  });

  final String? documentId;
  final bool isBusy;
  final VoidCallback onAttach;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (documentId == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onAttach,
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Allega scontrino'),
        ),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.receipt_long_outlined),
      title: const Text('Scontrino allegato'),
      onTap: onOpen,
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Rimuovi',
        onPressed: onRemove,
      ),
    );
  }
}
