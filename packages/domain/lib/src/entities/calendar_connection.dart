/// Collegamento dell'utente a Google Calendar (Fase 3, "Sync con Google
/// Calendar" — integrazione richiesta esplicitamente). Legato all'utente, non
/// a un Workspace: un solo account Google per utente, come `push_subscriptions`.
/// Il refresh token OAuth non fa parte di questa entità — non lascia mai le
/// Edge Function che lo usano, il client non lo legge né lo vede mai (vedi
/// `CalendarSyncRepository`).
final class CalendarConnection {
  const CalendarConnection({
    required this.googleCalendarId,
    required this.createdAt,
    this.lastSyncedAt,
  });

  /// Sempre `'primary'` in questa slice: nessuna selezione di un calendario
  /// specifico tra quelli dell'account Google collegato.
  final String googleCalendarId;
  final DateTime createdAt;

  /// Ultima volta che `pull-google-calendar-events` ha letto con successo gli
  /// eventi di questo account — `null` se non è mai stata eseguita una pull.
  final DateTime? lastSyncedAt;

  @override
  bool operator ==(Object other) =>
      other is CalendarConnection &&
      other.googleCalendarId == googleCalendarId &&
      other.createdAt == createdAt &&
      other.lastSyncedAt == lastSyncedAt;

  @override
  int get hashCode => Object.hash(googleCalendarId, createdAt, lastSyncedAt);

  @override
  String toString() =>
      'CalendarConnection(googleCalendarId: $googleCalendarId, lastSyncedAt: $lastSyncedAt)';
}
