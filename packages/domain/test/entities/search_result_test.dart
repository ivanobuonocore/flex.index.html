import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  group('SearchResult', () {
    test('due risultati con stessi campi sono uguali per valore', () {
      const a = SearchResult(
        type: SearchResultType.note,
        id: 'n1',
        workspaceId: 'w1',
        title: 'Idea',
        snippet: 'contenuto',
      );
      const b = SearchResult(
        type: SearchResultType.note,
        id: 'n1',
        workspaceId: 'w1',
        title: 'Idea',
        snippet: 'contenuto',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('type diverso distingue due risultati altrimenti identici', () {
      const asNote = SearchResult(
        type: SearchResultType.note,
        id: 'x1',
        workspaceId: 'w1',
        title: 'Contratto',
      );
      const asDocument = SearchResult(
        type: SearchResultType.document,
        id: 'x1',
        workspaceId: 'w1',
        title: 'Contratto',
      );

      expect(asNote, isNot(equals(asDocument)));
    });
  });
}
