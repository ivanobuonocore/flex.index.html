import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [AuthRepository] su Supabase Auth (Software
/// Architecture, "Sicurezza" — Email/Google/Apple; solo Email in Fase 1).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Stream<User?> watchCurrentUser() {
    late final StreamController<User?> controller;
    late final StreamSubscription<supabase.AuthState> subscription;

    controller = StreamController<User?>.broadcast(
      onListen: () {
        controller.add(_toDomainUser(_client.auth.currentSession?.user));
        subscription = _client.auth.onAuthStateChange.listen(
          (state) => controller.add(_toDomainUser(state.session?.user)),
          onError: controller.addError,
        );
      },
      onCancel: () => subscription.cancel(),
    );

    return controller.stream;
  }

  @override
  Future<Result<User>> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = _toDomainUser(response.user);
      if (user == null) {
        return const Result.err(AuthFailure('Credenziali non valide.'));
      }
      return Result.ok(user);
    } on supabase.AuthException catch (e) {
      return Result.err(AuthFailure(_readableMessage(e), cause: e));
    } catch (e) {
      return Result.err(
          UnexpectedFailure('Accesso non riuscito. Riprova.', cause: e));
    }
  }

  @override
  Future<Result<User>> signUpWithPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      // `response.user` è quasi sempre valorizzato anche quando serve
      // confermare l'email (l'account esiste già, solo non ancora attivo):
      // il segnale corretto è `response.session` — resta null finché
      // l'utente non conferma, non `response.user`. Controllare `user ==
      // null` (come faceva la versione precedente) faceva sembrare la
      // registrazione riuscita subito, senza mostrare alcun messaggio.
      if (response.session == null) {
        return const Result.err(
          AuthFailure(
            'Ti abbiamo inviato un\'email di conferma: clicca sul link per '
            'completare la registrazione (controlla anche nella posta '
            'indesiderata/spam se non la vedi).',
          ),
        );
      }
      final user = _toDomainUser(response.user);
      if (user == null) {
        return const Result.err(
          UnexpectedFailure('Registrazione non riuscita. Riprova.'),
        );
      }
      return Result.ok(user);
    } on supabase.AuthException catch (e) {
      return Result.err(AuthFailure(_readableMessage(e), cause: e));
    } catch (e) {
      return Result.err(
          UnexpectedFailure('Registrazione non riuscita. Riprova.', cause: e));
    }
  }

  @override
  Future<Result<Unit>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(UnexpectedFailure(
          'Non è stato possibile uscire. Riprova.',
          cause: e));
    }
  }

  @override
  Future<Result<Unit>> updateThemeMode(AppThemeMode mode) async {
    try {
      // Metadata dell'utenza (stesso meccanismo già usato per `name` alla
      // registrazione), non una nuova tabella: la preferenza di tema è
      // globale all'utente, non legata a un Workspace (CLAUDE.md). Il
      // risultato si riflette in `watchCurrentUser` tramite l'evento
      // `userUpdated` che Supabase Auth emette su `onAuthStateChange`.
      await _client.auth.updateUser(
        supabase.UserAttributes(data: {'theme_mode': mode.name}),
      );
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(UnexpectedFailure(
          'Non è stato possibile salvare la preferenza di tema. Riprova.',
          cause: e));
    }
  }

  @override
  Future<Result<Unit>> completeOnboarding() async {
    try {
      await _client.auth.updateUser(
        supabase.UserAttributes(data: {'onboarding_completed': true}),
      );
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(UnexpectedFailure(
          'Non è stato possibile salvare la preferenza. Riprova.',
          cause: e));
    }
  }

  User? _toDomainUser(supabase.User? authUser) {
    if (authUser == null) return null;
    final metadataName = (authUser.userMetadata?['name'] as String?)?.trim();
    final displayName = (metadataName == null || metadataName.isEmpty)
        ? (authUser.email ?? 'Utente')
        : metadataName;

    return User(
      id: authUser.id,
      email: authUser.email ?? '',
      name: displayName,
      plan: UserPlan.free,
      createdAt: DateTime.tryParse(authUser.createdAt) ?? DateTime.now(),
      lastSeenAt: authUser.lastSignInAt != null
          ? DateTime.tryParse(authUser.lastSignInAt!)
          : null,
      themeMode: _themeModeFromMetadata(authUser.userMetadata?['theme_mode']),
      onboardingCompleted:
          authUser.userMetadata?['onboarding_completed'] == true,
    );
  }

  AppThemeMode _themeModeFromMetadata(Object? value) => switch (value) {
        'light' => AppThemeMode.light,
        'dark' => AppThemeMode.dark,
        _ => AppThemeMode.system,
      };

  /// Messaggio comprensibile all'utente; il dettaglio tecnico resta in
  /// [Failure.cause] per il logging (AI Engineering Playbook, "Error Handling").
  String _readableMessage(supabase.AuthException e) {
    switch (e.statusCode) {
      case '400':
      case '422':
        return 'Email o password non validi.';
      case '429':
        return 'Troppi tentativi. Riprova tra qualche minuto.';
      default:
        return 'Si è verificato un problema. Riprova tra poco.';
    }
  }
}
