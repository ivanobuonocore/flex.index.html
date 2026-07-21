import 'package:pip_shared/pip_shared.dart';

import '../entities/user.dart';
import '../enums.dart';

/// Confine verso l'identity provider, implementato nel layer `data` di ogni
/// app (Dependency Inversion — Engineering Constitution, Articolo 4).
abstract interface class AuthRepository {
  /// Utente autenticato correntemente, `null` se nessuna sessione è attiva.
  Stream<User?> watchCurrentUser();

  Future<Result<User>> signInWithPassword({
    required String email,
    required String password,
  });

  Future<Result<User>> signUpWithPassword({
    required String email,
    required String password,
    required String name,
  });

  Future<Result<Unit>> signOut();

  /// Aggiorna la preferenza di tema dell'utente (richiesta esplicita
  /// dell'utente: "tema chiaro/scuro"). Il nuovo valore si riflette nello
  /// stream di [watchCurrentUser] appena l'identity provider conferma
  /// l'aggiornamento — nessuno stato locale duplicato qui.
  Future<Result<Unit>> updateThemeMode(AppThemeMode mode);
}
