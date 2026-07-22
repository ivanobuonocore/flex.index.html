import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

/// Doppio di test per [AuthRepository]: nessuna dipendenza da Supabase, in
/// linea con l'Engineering Constitution, Articolo 7 (Testabilità).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.signInResult, this.signUpResult});

  final _controller = StreamController<User?>.broadcast();

  Result<User>? signInResult;
  Result<User>? signUpResult;
  Result<Unit>? updateThemeModeResult;
  Result<Unit>? completeOnboardingResult;
  bool signOutCalled = false;
  bool completeOnboardingCalled = false;
  AppThemeMode? lastThemeMode;

  void emit(User? user) => _controller.add(user);

  @override
  Stream<User?> watchCurrentUser() => _controller.stream;

  @override
  Future<Result<User>> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final result = signInResult ??
        const Result<User>.err(
            AuthFailure('Nessun risultato configurato nel fake.'));
    if (result.isOk) {
      emit((result as Ok<User>).value);
    }
    return result;
  }

  @override
  Future<Result<User>> signUpWithPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    final result = signUpResult ??
        const Result<User>.err(
            AuthFailure('Nessun risultato configurato nel fake.'));
    if (result.isOk) {
      emit((result as Ok<User>).value);
    }
    return result;
  }

  @override
  Future<Result<Unit>> signOut() async {
    signOutCalled = true;
    emit(null);
    return const Result.ok(unit);
  }

  @override
  Future<Result<Unit>> updateThemeMode(AppThemeMode mode) async {
    lastThemeMode = mode;
    return updateThemeModeResult ?? const Result.ok(unit);
  }

  @override
  Future<Result<Unit>> completeOnboarding() async {
    completeOnboardingCalled = true;
    return completeOnboardingResult ?? const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
