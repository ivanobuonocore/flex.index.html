import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Note di un Workspace, in tempo reale (Software Architecture,
/// "Sincronizzazione" — Realtime lato Supabase).
final notesProvider =
    StreamProvider.autoDispose.family<List<Note>, String>((ref, workspaceId) {
  return ref.watch(noteRepositoryProvider).watchNotes(workspaceId);
});

final noteFormControllerProvider =
    AsyncNotifierProvider.autoDispose<NoteFormController, void>(
        NoteFormController.new);

class NoteFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Failure?> create({
    required String workspaceId,
    required String title,
    String content = '',
    List<String> tags = const [],
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(noteRepositoryProvider).createNote(
          workspaceId: workspaceId,
          title: title,
          content: content,
          tags: tags,
        );
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  Future<Failure?> updateNote(Note note) async {
    state = const AsyncLoading();
    final result = await ref.read(noteRepositoryProvider).updateNote(note);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  Future<Failure?> delete(String noteId) async {
    state = const AsyncLoading();
    final result = await ref.read(noteRepositoryProvider).deleteNote(noteId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}
