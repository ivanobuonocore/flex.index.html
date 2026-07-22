import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeNoteRepository implements NoteRepository {
  FakeNoteRepository({this.createResult});

  final _controller = StreamController<List<Note>>.broadcast();
  Result<Note>? createResult;
  Note? lastCreated;
  Note? lastUpdated;
  String? lastDeletedId;
  List<String>? lastCreatedTags;

  void emit(List<Note> notes) => _controller.add(notes);

  @override
  Stream<List<Note>> watchNotes(String workspaceId) => _controller.stream;

  @override
  Future<Result<Note>> createNote({
    required String workspaceId,
    required String title,
    String content = '',
    List<String> tags = const [],
  }) async {
    lastCreatedTags = tags;
    final result = createResult ??
        const Result<Note>.err(
            ValidationFailure('Nessun risultato configurato.'));
    if (result.isOk) {
      lastCreated = (result as Ok<Note>).value;
    }
    return result;
  }

  @override
  Future<Result<Note>> updateNote(Note note) async {
    lastUpdated = note;
    return Result.ok(note);
  }

  @override
  Future<Result<Unit>> deleteNote(String noteId) async {
    lastDeletedId = noteId;
    return const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
