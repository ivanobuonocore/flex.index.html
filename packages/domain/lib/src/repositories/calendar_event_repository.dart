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
}
