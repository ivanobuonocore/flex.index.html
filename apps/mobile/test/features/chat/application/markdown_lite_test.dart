import 'package:flutter_test/flutter_test.dart';
import 'package:pip_mobile/features/chat/application/markdown_lite.dart';

void main() {
  group('containsMarkdownLite', () {
    test('nessun marcatore: false', () {
      expect(containsMarkdownLite('Ciao, come va?'), isFalse);
    });

    test('con grassetto: true', () {
      expect(containsMarkdownLite('Ciao **mondo**'), isTrue);
    });

    test('con elenco puntato: true', () {
      expect(containsMarkdownLite('Ecco la lista:\n- Latte\n- Pane'), isTrue);
    });
  });

  group('parseMarkdownLite', () {
    test('grassetto semplice', () {
      final lines = parseMarkdownLite('Ciao **mondo**!');

      expect(lines, hasLength(1));
      expect(lines.first.isBullet, isFalse);
      expect(lines.first.spans.map((s) => (s.text, s.bold)), [
        ('Ciao ', false),
        ('mondo', true),
        ('!', false),
      ]);
    });

    test('** non bilanciati restano testo letterale', () {
      final lines = parseMarkdownLite('Attenzione ** a questo');

      expect(lines.first.spans.map((s) => (s.text, s.bold)), [
        ('Attenzione ** a questo', false),
      ]);
    });

    test('elenco puntato', () {
      final lines = parseMarkdownLite('- Latte\n- Pane');

      expect(lines, hasLength(2));
      expect(lines[0].isBullet, isTrue);
      expect(lines[0].spans.single.text, 'Latte');
      expect(lines[1].isBullet, isTrue);
      expect(lines[1].spans.single.text, 'Pane');
    });

    test('nessun marcatore: passthrough su un unico frammento non in grassetto',
        () {
      final lines = parseMarkdownLite('Ciao, come va?');

      expect(lines, hasLength(1));
      expect(lines.first.isBullet, isFalse);
      expect(lines.first.spans.single.text, 'Ciao, come va?');
      expect(lines.first.spans.single.bold, isFalse);
    });
  });
}
