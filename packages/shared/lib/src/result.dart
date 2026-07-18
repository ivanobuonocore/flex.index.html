import 'failure.dart';

/// Esito esplicito di un'operazione che può fallire, senza ricorrere a eccezioni
/// non gestite tra i livelli dell'applicazione.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// Applica [onOk] o [onErr] a seconda dell'esito, senza controlli manuali del tipo.
  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) {
    final self = this;
    if (self is Ok<T>) return onOk(self.value);
    if (self is Err<T>) return onErr(self.failure);
    throw StateError('Result non riconosciuto: $self');
  }

  /// Trasforma il valore di successo, propagando l'errore invariato.
  Result<R> map<R>(R Function(T value) transform) {
    return fold(
      (value) => Result.ok(transform(value)),
      (failure) => Result.err(failure),
    );
  }
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err, failure);
}
