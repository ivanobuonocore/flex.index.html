import 'package:pip_shared/pip_shared.dart';

import '../entities/calendar_event.dart';

/// Confine verso la persistenza dei Promemoria (Calendar Event), implementato
/// nel layer `data` di ogni app (Dependency Inversion — Engineering
/// Constitution, Articolo 4).
abstract interface class CalendarEventRepository {
  /// Promemoria del Workspace [workspaceId], ordinati per data.
  Stream<List<CalendarEvent>> watchEvents(String workspaceId);

  Future<Result<CalendarEvent>> createEvent({
    required String workspaceId,
    required String title,
    required DateTime startsAt,
    int durationMinutes = 30,
    int? reminderMinutesBefore,
    String? sourceChatId,
  });

  /// Soft delete (Domain Model, "Principi del modello").
  Future<Result<Unit>> deleteEvent(String eventId);

  /// Soft delete di tutte le occorrenze con lo stesso [recurrenceGroupId]
  /// (richiesta esplicita dell'utente: "eliminare un'intera serie di
  /// promemoria ricorrenti", non una occorrenza alla volta).
  Future<Result<Unit>> deleteRecurrenceGroup(String recurrenceGroupId);

  /// Sincronizza (crea o cancella) l'evento [eventId] su Google Calendar, se
  /// l'utente ha collegato un account (Fase 3, "Sync con Google Calendar" —
  /// integrazione richiesta esplicitamente). Interamente best-effort come
  /// [BudgetRepository.checkBudgetAlert]: nessun [Failure] bloccante mai
  /// propagato — la Edge Function decide da sé se l'utente è collegato,
  /// senza che il chiamante debba saperlo.
  Future<Result<Unit>> syncToGoogleCalendar({
    required String eventId,
    required bool deleted,
  });
}
