/// Evento di calendario in un Workspace (Domain Model, entità Calendar
/// Event). Prima implementazione reale in Fase 3, "Promemoria via Chat" —
/// richiesta esplicita dell'utente di notifiche push vere, non un semplice
/// elenco in app.
final class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.startsAt,
    required this.durationMinutes,
    required this.createdAt,
    this.reminderMinutesBefore,
    this.sourceTaskId,
    this.sourceChatId,
    this.notifiedAt,
    this.recurrenceGroupId,
    this.deletedAt,
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
  final DateTime createdAt;

  /// Valorizzato dalla Edge Function `send-due-reminders` non appena la
  /// notifica push è stata inviata — evita di inviarla due volte allo stesso
  /// evento (il cron gira ogni minuto).
  final DateTime? notifiedAt;

  /// Accomuna le occorrenze di un promemoria ricorrente (richiesta esplicita
  /// dell'utente: "ogni lunedì", "ogni mese") — `null` per un promemoria
  /// singolo. Solo informativo in questa slice (mostra un badge "ricorrente"):
  /// ogni occorrenza resta una riga indipendente, eliminabile singolarmente.
  final String? recurrenceGroupId;

  /// Soft delete (Domain Model, "Principi del modello").
  final DateTime? deletedAt;

  CalendarEvent copyWith({
    String? title,
    DateTime? startsAt,
    int? durationMinutes,
    int? reminderMinutesBefore,
  }) {
    return CalendarEvent(
      id: id,
      workspaceId: workspaceId,
      title: title ?? this.title,
      startsAt: startsAt ?? this.startsAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      sourceTaskId: sourceTaskId,
      sourceChatId: sourceChatId,
      createdAt: createdAt,
      notifiedAt: notifiedAt,
      recurrenceGroupId: recurrenceGroupId,
      deletedAt: deletedAt,
    );
  }

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
      other.sourceChatId == sourceChatId &&
      other.createdAt == createdAt &&
      other.notifiedAt == notifiedAt &&
      other.recurrenceGroupId == recurrenceGroupId &&
      other.deletedAt == deletedAt;

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
        createdAt,
        notifiedAt,
        recurrenceGroupId,
        deletedAt,
      );

  @override
  String toString() =>
      'CalendarEvent(id: $id, title: $title, startsAt: $startsAt)';
}
