/// Evento di calendario in un Workspace (Domain Model, entità Calendar Event).
final class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.startsAt,
    required this.durationMinutes,
    this.reminderMinutesBefore,
    this.sourceTaskId,
    this.sourceChatId,
  });

  final String id;
  final String workspaceId;
  final String title;
  final DateTime startsAt;
  final int durationMinutes;
  final int? reminderMinutesBefore;

  /// Origine dell'evento se derivato da una Task o da una conversazione.
  final String? sourceTaskId;
  final String? sourceChatId;

  @override
  bool operator ==(Object other) =>
      other is CalendarEvent &&
      other.id == id &&
      other.workspaceId == workspaceId &&
      other.title == title &&
      other.startsAt == startsAt &&
      other.durationMinutes == durationMinutes &&
      other.reminderMinutesBefore == reminderMinutesBefore &&
      other.sourceTaskId == sourceTaskId &&
      other.sourceChatId == sourceChatId;

  @override
  int get hashCode => Object.hash(
        id,
        workspaceId,
        title,
        startsAt,
        durationMinutes,
        reminderMinutesBefore,
        sourceTaskId,
        sourceChatId,
      );

  @override
  String toString() =>
      'CalendarEvent(id: $id, title: $title, startsAt: $startsAt)';
}
