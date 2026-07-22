import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

/// Fake a valore singolo (non broadcast) per i repository letti da
/// `DataExportController.generate()` — a differenza degli altri `fake_*` di
/// questa cartella (pensati per un singolo `StreamProvider.family` alla
/// volta, con un broadcast `StreamController` condiviso indipendentemente
/// dal `workspaceId`), qui `generate()` fa più `.first` sequenziali su più
/// Workspace nella stessa chiamata: uno stream a valore singolo per
/// `workspaceId` evita la sincronizzazione manuale dell'emissione che
/// servirebbe con un controller broadcast condiviso.
class FakeInstantWorkspaceRepository implements WorkspaceRepository {
  FakeInstantWorkspaceRepository(this.workspaces);
  final List<Workspace> workspaces;

  @override
  Stream<List<Workspace>> watchWorkspaces() => Stream.value(workspaces);

  @override
  Future<Result<Workspace>> createWorkspace(
          {required String name,
          required String icon,
          String? description,
          String? category,
          String? color}) =>
      throw UnimplementedError();

  @override
  Future<Result<Workspace>> updateWorkspace(Workspace workspace) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit>> archiveWorkspace(String workspaceId) =>
      throw UnimplementedError();
}

class FakeInstantNoteRepository implements NoteRepository {
  FakeInstantNoteRepository(this.byWorkspace);
  final Map<String, List<Note>> byWorkspace;

  @override
  Stream<List<Note>> watchNotes(String workspaceId) =>
      Stream.value(byWorkspace[workspaceId] ?? const []);

  @override
  Future<Result<Note>> createNote(
          {required String workspaceId,
          required String title,
          String content = '',
          List<String> tags = const []}) =>
      throw UnimplementedError();

  @override
  Future<Result<Note>> updateNote(Note note) => throw UnimplementedError();

  @override
  Future<Result<Unit>> deleteNote(String noteId) => throw UnimplementedError();
}

class FakeInstantTaskRepository implements TaskRepository {
  FakeInstantTaskRepository(this.byWorkspace);
  final Map<String, List<Task>> byWorkspace;

  @override
  Stream<List<Task>> watchTasks(String workspaceId) =>
      Stream.value(byWorkspace[workspaceId] ?? const []);

  @override
  Future<Result<Task>> createTask(
          {required String workspaceId,
          required String title,
          String? description,
          TaskPriority priority = TaskPriority.medium,
          DateTime? dueAt}) =>
      throw UnimplementedError();

  @override
  Future<Result<Task>> updateTask(Task task) => throw UnimplementedError();

  @override
  Future<Result<Unit>> deleteTask(String taskId) => throw UnimplementedError();
}

class FakeInstantDocumentRepository implements DocumentRepository {
  FakeInstantDocumentRepository(this.byWorkspace);
  final Map<String, List<Document>> byWorkspace;

  @override
  Stream<List<Document>> watchDocuments(String workspaceId) =>
      Stream.value(byWorkspace[workspaceId] ?? const []);

  @override
  Future<Result<Document>> uploadDocument(
          {required String workspaceId,
          required String fileName,
          required String mimeType,
          required bytes,
          String? chatId}) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit>> deleteDocument(String documentId) =>
      throw UnimplementedError();

  @override
  Future<Result<String>> getDownloadUrl(Document document) =>
      throw UnimplementedError();

  @override
  Future<Result<Document>> getDocument(String documentId) =>
      throw UnimplementedError();

  @override
  Future<Result<Document>> updateTags(
          {required String documentId, required List<String> tags}) =>
      throw UnimplementedError();
}

class FakeInstantCalendarEventRepository implements CalendarEventRepository {
  FakeInstantCalendarEventRepository(this.byWorkspace);
  final Map<String, List<CalendarEvent>> byWorkspace;

  @override
  Stream<List<CalendarEvent>> watchEvents(String? workspaceId) => Stream.value(
      workspaceId == null ? const [] : byWorkspace[workspaceId] ?? const []);

  @override
  Future<Result<CalendarEvent>> createEvent(
          {required String workspaceId,
          required String title,
          required DateTime startsAt,
          int durationMinutes = 30,
          int? reminderMinutesBefore,
          String? sourceChatId}) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit>> deleteEvent(String eventId) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit>> deleteRecurrenceGroup(String recurrenceGroupId) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit>> syncToGoogleCalendar(
          {required String eventId, required bool deleted}) =>
      throw UnimplementedError();
}

class FakeInstantMemoryRepository implements MemoryRepository {
  FakeInstantMemoryRepository(
      {this.global = const [], this.byWorkspace = const {}});
  final List<Memory> global;
  final Map<String, List<Memory>> byWorkspace;

  @override
  Stream<List<Memory>> watchGlobalMemories() => Stream.value(global);

  @override
  Stream<List<Memory>> watchWorkspaceMemories(String workspaceId) =>
      Stream.value(byWorkspace[workspaceId] ?? const []);

  @override
  Future<Result<Memory>> createWorkspaceMemory(
          {required String workspaceId, required String content}) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit>> deleteMemory(String memoryId) =>
      throw UnimplementedError();
}

class FakeInstantTransactionRepository implements TransactionRepository {
  FakeInstantTransactionRepository(this.transactions);
  final List<Transaction> transactions;

  @override
  Stream<List<Transaction>> watchTransactions(String? workspaceId) =>
      Stream.value(transactions);

  @override
  Future<Result<Transaction>> createTransaction(
          {required String workspaceId,
          required TransactionType type,
          required String description,
          required int amountCents,
          String currency = 'EUR',
          required DateTime occurredAt,
          TransactionCategory category = TransactionCategory.altro,
          List<String> tags = const []}) =>
      throw UnimplementedError();

  @override
  Future<Result<Transaction>> updateTransaction(Transaction transaction) =>
      throw UnimplementedError();

  @override
  Future<Result<Transaction>> confirmTransaction(String transactionId) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit>> deleteTransaction(String transactionId) =>
      throw UnimplementedError();

  @override
  Future<Result<Transaction>> attachDocument(
          {required String transactionId, required String? documentId}) =>
      throw UnimplementedError();

  @override
  Future<Result<ReceiptExtraction?>> extractReceiptData(String documentId) =>
      throw UnimplementedError();
}
