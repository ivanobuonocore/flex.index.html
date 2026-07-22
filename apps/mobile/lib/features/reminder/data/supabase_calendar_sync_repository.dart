import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [CalendarSyncRepository] su Supabase Auth/Postgres.
///
/// Ascolta da sé i cambi di sessione (`onAuthStateChange`) fin dalla
/// costruzione: Supabase espone `session.providerRefreshToken` solo nel
/// primo evento subito dopo un `linkIdentity` riuscito, mai persistito lato
/// client — se questo repository non fosse già "vivo" in quel momento (letto
/// almeno una volta, es. dalla schermata Profilo), il token catturato
/// andrebbe perso. Nel flusso reale dell'app l'utente è necessariamente
/// sulla schermata da cui ha toccato "Connetti" quando torna dal redirect,
/// quindi il provider è già stato letto e questo listener è già attivo.
class SupabaseCalendarSyncRepository implements CalendarSyncRepository {
  SupabaseCalendarSyncRepository(this._client) {
    _authSubscription = _client.auth.onAuthStateChange.listen((state) {
      final token = state.session?.providerRefreshToken;
      if (token != null && token.isNotEmpty) {
        _captureConnection(token);
      }
    });
  }

  final supabase.SupabaseClient _client;
  late final StreamSubscription<supabase.AuthState> _authSubscription;

  static const _table = 'calendar_connections';
  static const _statusFunction = 'get_my_calendar_connection';

  @override
  Future<Result<CalendarConnection?>> fetchConnectionStatus() async {
    try {
      final rows = await _client.rpc(_statusFunction) as List<dynamic>;
      if (rows.isEmpty) return const Result.ok(null);
      final row = rows.first as Map<String, dynamic>;
      return Result.ok(CalendarConnection(
        googleCalendarId: row['google_calendar_id'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        lastSyncedAt: row['last_synced_at'] != null
            ? DateTime.parse(row['last_synced_at'] as String)
            : null,
      ));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile leggere il collegamento.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Unit>> beginConnect() async {
    try {
      await _client.auth.linkIdentity(
        supabase.OAuthProvider.google,
        scopes: 'https://www.googleapis.com/auth/calendar.events',
      );
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure(
            'Non è stato possibile avviare il collegamento a Google.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Unit>> disconnect() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const Result.err(
          AuthFailure('Devi accedere per scollegare Google Calendar.'));
    }
    try {
      await _client.from(_table).delete().eq('user_id', userId);
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile scollegare Google Calendar.',
            cause: e),
      );
    }
  }

  Future<void> _captureConnection(String refreshToken) async {
    // Best-effort: un errore qui (funzione non deployata, rete assente)
    // lascia semplicemente il collegamento non salvato — l'utente può
    // ritoccare "Connetti" e ritentare, nessun altro flusso ne dipende.
    try {
      await _client.functions.invoke('save-calendar-connection', body: {
        'refreshToken': refreshToken,
      });
    } catch (_) {
      // Ignorato deliberatamente: vedi commento sopra.
    }
  }

  void dispose() => _authSubscription.cancel();
}
