import 'package:pip_shared/pip_shared.dart';

import '../entities/note.dart';

/// Confine verso la persistenza delle Note, implementato nel layer `data` di
/// ogni app (Dependency Inversion — Engineering Constitution, Articolo 4).
abstract interface class NoteRepository {
  /// Note del Workspace [workspaceId], ordinate per ultima modifica.
  Stream<List<Note>> watchNotes(String workspaceId);

  Future<Result<Note>> createNote({
    required String workspaceId,
    required String title,
    String content = '',
    List<String> tags = const [],
  });

  Future<Result<Note>> updateNote(Note note);

  /// Soft delete (Domain Model, "Principi del modello").
  Future<Result<Unit>> deleteNote(String noteId);
}
