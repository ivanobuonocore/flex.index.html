import 'package:pip_shared/pip_shared.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('Ok.fold esegue il ramo di successo', () {
      const result = Result<int>.ok(42);

      final output = result.fold(
          (value) => 'ok:$value', (failure) => 'err:${failure.message}');

      expect(output, 'ok:42');
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
    });

    test('Err.fold esegue il ramo di errore', () {
      const result = Result<int>.err(ValidationFailure('nome obbligatorio'));

      final output = result.fold(
          (value) => 'ok:$value', (failure) => 'err:${failure.message}');

      expect(output, 'err:nome obbligatorio');
      expect(result.isErr, isTrue);
    });

    test('map trasforma solo il valore di successo', () {
      const ok = Result<int>.ok(2);
      const err = Result<int>.err(NetworkFailure('offline'));

      expect(ok.map((v) => v * 10), const Ok<int>(20));
      expect(err.map((v) => v * 10), const Err<int>(NetworkFailure('offline')));
    });
  });
}
