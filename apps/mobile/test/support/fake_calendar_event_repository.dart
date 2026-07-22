import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeCalendarEventRepository implements CalendarEventRepository {
  FakeCalendarEventRepository({this.createResult});

  final _controller = StreamController<List<CalendarEvent>>.broadcast();
  Result<CalendarEvent>? createResult;
  CalendarEvent? lastCreated;
  String? lastDeletedId;
  String? lastDeletedRecurrenceGroupId;

  void emit(List<CalendarEvent> events) => _controller.add(events);

  @override
  Stream<List<CalendarEvent>> watchEvents(String workspaceId) =>
      _controller.stream;

  @override
  Future<Result<CalendarEvent>> createEvent({
    required String workspaceId,
    required String title,
    required DateTime startsAt,
    int durationMinutes = 30,
    int? reminderMinutesBefore,
    String? sourceChatId,
  }) async {
    final result = createResult ??
        const Result<CalendarEvent>.err(
            ValidationFailure('Nessun risultato configurato.'));
    if (result.isOk) {
      lastCreated = (result as Ok<CalendarEvent>).value;
    }
    return result;
  }

  @override
  Future<Result<Unit>> deleteEvent(String eventId) async {
    lastDeletedId = eventId;
    return const Result.ok(unit);
  }

  @override
  Future<Result<Unit>> deleteRecurrenceGroup(String recurrenceGroupId) async {
    lastDeletedRecurrenceGroupId = recurrenceGroupId;
    return const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
