import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../core/providers.dart';

final dataExportControllerProvider =
    AsyncNotifierProvider.autoDispose<DataExportController, String?>(
        DataExportController.new);

/// Export completo dei dati dell'utente in JSON (richiesta esplicita:
/// "esportare tutti i miei dati") — Note/Attività/Documenti (solo metadata,
/// non i file: niente accesso a Storage da qui)/Promemoria/Memoria per ogni
/// Workspace, più Transazioni e Memoria globale. Lettura one-shot (`.first`
/// su ogni stream): un export è uno snapshot del momento in cui viene
/// richiesto, non deve restare in ascolto realtime come il resto dell'app.
class DataExportController extends AutoDisposeAsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  Future<void> generate() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final workspaces =
          await ref.read(workspaceRepositoryProvider).watchWorkspaces().first;
      final noteRepo = ref.read(noteRepositoryProvider);
      final taskRepo = ref.read(taskRepositoryProvider);
      final documentRepo = ref.read(documentRepositoryProvider);
      final eventRepo = ref.read(calendarEventRepositoryProvider);
      final memoryRepo = ref.read(memoryRepositoryProvider);

      final workspaceExports = <Map<String, dynamic>>[];
      for (final workspace in workspaces) {
        final notes = await noteRepo.watchNotes(workspace.id).first;
        final tasks = await taskRepo.watchTasks(workspace.id).first;
        final documents = await documentRepo.watchDocuments(workspace.id).first;
        final events = await eventRepo.watchEvents(workspace.id).first;
        final workspaceMemories =
            await memoryRepo.watchWorkspaceMemories(workspace.id).first;

        workspaceExports.add({
          'id': workspace.id,
          'name': workspace.name,
          'category': workspace.category,
          'createdAt': workspace.createdAt.toIso8601String(),
          'notes': notes.map(_noteToJson).toList(),
          'tasks': tasks.map(_taskToJson).toList(),
          'documents': documents.map(_documentToJson).toList(),
          'reminders': events.map(_eventToJson).toList(),
          'memories': workspaceMemories.map(_memoryToJson).toList(),
        });
      }

      final transactions = await ref
          .read(transactionRepositoryProvider)
          .watchTransactions(null)
          .first;
      final globalMemories =
          await ref.read(memoryRepositoryProvider).watchGlobalMemories().first;

      final export = {
        'exportedAt': DateTime.now().toIso8601String(),
        'workspaces': workspaceExports,
        'transactions': transactions.map(_transactionToJson).toList(),
        'globalMemories': globalMemories.map(_memoryToJson).toList(),
      };

      return const JsonEncoder.withIndent('  ').convert(export);
    });
  }
}

Map<String, dynamic> _noteToJson(Note note) => {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'tags': note.tags,
      'updatedAt': note.updatedAt.toIso8601String(),
    };

Map<String, dynamic> _taskToJson(Task task) => {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'status': task.status.name,
      'priority': task.priority.name,
      'dueAt': task.dueAt?.toIso8601String(),
      'createdAt': task.createdAt.toIso8601String(),
    };

/// Solo metadata (nome, dimensione, data): il contenuto del file resta in
/// Storage, un export JSON non è il posto giusto per portare byte binari.
Map<String, dynamic> _documentToJson(Document document) => {
      'id': document.id,
      'name': document.name,
      'mimeType': document.mimeType,
      'sizeBytes': document.sizeBytes,
      'uploadedAt': document.uploadedAt.toIso8601String(),
    };

Map<String, dynamic> _eventToJson(CalendarEvent event) => {
      'id': event.id,
      'title': event.title,
      'startsAt': event.startsAt.toIso8601String(),
      'durationMinutes': event.durationMinutes,
      'recurring': event.recurrenceGroupId != null,
    };

Map<String, dynamic> _memoryToJson(Memory memory) => {
      'id': memory.id,
      'content': memory.content,
      'updatedAt': memory.updatedAt.toIso8601String(),
    };

Map<String, dynamic> _transactionToJson(Transaction transaction) => {
      'id': transaction.id,
      'workspaceId': transaction.workspaceId,
      'type': transaction.type.name,
      'category': transaction.category.name,
      'description': transaction.description,
      'amountCents': transaction.amountCents,
      'currency': transaction.currency,
      'occurredAt': transaction.occurredAt.toIso8601String(),
      'status': transaction.status.name,
    };
