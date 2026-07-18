/// Valore singleton per operazioni che completano senza un risultato
/// significativo (es. `Result<Unit>` al posto di `Result<void>`, che non è
/// un tipo generico valido per un valore memorizzato).
final class Unit {
  const Unit._();
}

const Unit unit = Unit._();
