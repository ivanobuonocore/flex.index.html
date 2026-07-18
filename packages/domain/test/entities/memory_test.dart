import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Memory', () {
    test('livello globale richiede userId', () {
      expect(
        () => Memory(
          id: 'm1',
          content: 'preferisce risposte concise',
          level: MemoryLevel.global,
          origin: MemoryOrigin.ai,
          updatedAt: DateTime.utc(2026, 1, 1),
          userId: 'u1',
        ),
        returnsNormally,
      );
    });

    test('livello globale senza userId viola l\'invariante di coerenza', () {
      expect(
        () => Memory(
          id: 'm1',
          content: 'preferisce risposte concise',
          level: MemoryLevel.global,
          origin: MemoryOrigin.ai,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
