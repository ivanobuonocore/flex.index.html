import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Azioni di autenticazione (login, registrazione, logout). Lo stato di
/// sessione risultante è osservato separatamente da [sessionControllerProvider]:
/// qui viviamo solo il ciclo di vita della singola richiesta.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Failure?> signIn(
      {required String email, required String password}) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .signInWithPassword(email: email, password: password);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  Future<Failure?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .signUpWithPassword(email: email, password: password, name: name);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }

  Future<Failure?> updateThemeMode(AppThemeMode mode) async {
    state = const AsyncLoading();
    final result =
        await ref.read(authRepositoryProvider).updateThemeMode(mode);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}
