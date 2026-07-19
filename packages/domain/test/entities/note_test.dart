import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Note', () {
    test('copyWith aggiorna i campi indicati e forza updatedAt', () {
      final note = Note(
        id: 'n1',
        workspaceId: 'w1',
        title: 'Idea',
        content: 'contenuto iniziale',
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final newUpdatedAt = DateTime.utc(2026, 1, 2);

      final edited = note.copyWith(
          content: 'contenuto aggiornato', updatedAt: newUpdatedAt);

      expect(edited.content, 'contenuto aggiornato');
      expect(edited.title, note.title);
      expect(edited.updatedAt, newUpdatedAt);
      expect(edited.id, note.id);
    });

    test('due note con stessi campi sono uguali per valore', () {
      final updatedAt = DateTime.utc(2026, 1, 1);
      final a = Note(
          id: 'n1',
          workspaceId: 'w1',
          title: 'Idea',
          content: 'x',
          updatedAt: updatedAt);
      final b = Note(
          id: 'n1',
          workspaceId: 'w1',
          title: 'Idea',
          content: 'x',
          updatedAt: updatedAt);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
