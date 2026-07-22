/// Markdown "lite" nelle risposte dell'assistente (richiesta esplicita
/// dell'utente, "anche solo migliorie grafiche"): solo grassetto `**testo**`
/// ed elenchi puntati (righe che iniziano con `- `) — non un parser Markdown
/// completo (niente link, codice inline, escaping: non necessario per
/// messaggi di chat brevi, al costo di una dipendenza in più come
/// `flutter_markdown`). Pure, testabile senza Flutter widget bindings:
/// ritorna un piano di rendering, non widget — il chiamante
/// (`_MessageBubble` in `chat_home_screen.dart`) decide se serve un `Text`
/// semplice o un `Text.rich`.
library;

/// `true` se [content] contiene almeno un marcatore riconosciuto — il
/// chiamante lo usa per decidere se un `Text` semplice basta (il caso
/// comune, incluso ogni messaggio senza formattazione) invece di passare
/// sempre a `Text.rich`, che romperebbe `find.text(...)` nei test esistenti.
bool containsMarkdownLite(String content) {
  return content.contains('**') || RegExp(r'(^|\n)- ').hasMatch(content);
}

/// Un frammento di testo di una riga, in grassetto o no.
class MarkdownSpan {
  const MarkdownSpan(this.text, {this.bold = false});

  final String text;
  final bool bold;
}

/// Una riga del messaggio, eventualmente un elenco puntato.
class MarkdownLine {
  const MarkdownLine(this.spans, {this.isBullet = false});

  final List<MarkdownSpan> spans;
  final bool isBullet;
}

final _boldPattern = RegExp(r'\*\*(.+?)\*\*');

/// Divide [content] in righe e, per ciascuna, in frammenti grassetto/normale.
/// Una riga che inizia con `- ` diventa un elenco puntato (il marcatore non
/// compare nel testo). `**` non bilanciati (nessuna chiusura) restano testo
/// letterale, non spariscono e non rompono il parsing del resto della riga.
List<MarkdownLine> parseMarkdownLite(String content) {
  return content.split('\n').map((line) {
    final isBullet = line.startsWith('- ');
    final text = isBullet ? line.substring(2) : line;
    return MarkdownLine(_parseBold(text), isBullet: isBullet);
  }).toList(growable: false);
}

List<MarkdownSpan> _parseBold(String text) {
  final spans = <MarkdownSpan>[];
  var cursor = 0;
  for (final match in _boldPattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(MarkdownSpan(text.substring(cursor, match.start)));
    }
    spans.add(MarkdownSpan(match.group(1)!, bold: true));
    cursor = match.end;
  }
  if (cursor < text.length || spans.isEmpty) {
    spans.add(MarkdownSpan(text.substring(cursor)));
  }
  return spans;
}
