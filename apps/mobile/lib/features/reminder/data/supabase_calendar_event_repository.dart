import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [CalendarEventRepository] su Supabase Postgres.
/// L'isolamento tra Workspace è garantito dalle policy RLS di
/// `calendar_events` (`infrastructure/supabase/migrations`), che verificano
/// il Workspace referenziato — non da un filtro applicativo qui sotto.
class SupabaseCalendarEventRepository implements CalendarEventRepository {
  SupabaseCalendarEventRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _table = 'calendar_events';

  @override
  Stream<List<CalendarEvent>> watchEvents(String workspaceId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('workspace_id', workspaceId)
        .order('starts_at', ascending: true)
        .map(
          (rows) => rows
              .where((row) => row['deleted_at'] == null)
              .map(_toDomain)
              .toList(growable: false),
        );
  }

  @override
  Future<Result<CalendarEvent>> createEvent({
    required String workspaceId,
    required String title,
    required DateTime startsAt,
    int durationMinutes = 30,
    int? reminderMinutesBefore,
    String? sourceChatId,
  }) async {
    if (title.trim().isEmpty) {
      return const Result.err(
          ValidationFailure('Il titolo del promemoria è obbligatorio.'));
    }

    try {
      final row = await _client
          .from(_table)
          .insert({
            'workspace_id': workspaceId,
            'title': title.trim(),
            'starts_at': startsAt.toIso8601String(),
            'duration_minutes': durationMinutes,
            'reminder_minutes_before': reminderMinutesBefore,
            'source_chat_id': sourceChatId,
          })
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile creare il promemoria.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Unit>> deleteEvent(String eventId) async {
    try {
      await _client.from(_table).update(
          {'deleted_at': DateTime.now().toIso8601String()}).eq('id', eventId);
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile eliminare il promemoria.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Unit>> deleteRecurrenceGroup(String recurrenceGroupId) async {
    try {
      await _client
          .from(_table)
          .update({'deleted_at': DateTime.now().toIso8601String()}).eq(
              'recurrence_group_id', recurrenceGroupId);
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure(
            'Non è stato possibile eliminare la serie di promemoria.',
            cause: e),
      );
    }
  }

  CalendarEvent _toDomain(Map<String, dynamic> row) {
    return CalendarEvent(
      id: row['id'] as String,
      workspaceId: row['workspace_id'] as String,
      title: row['title'] as String,
      startsAt: DateTime.parse(row['starts_at'] as String),
      durationMinutes: row['duration_minutes'] as int,
      reminderMinutesBefore: row['reminder_minutes_before'] as int?,
      sourceTaskId: row['source_task_id'] as String?,
      sourceChatId: row['source_chat_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      notifiedAt: row['notified_at'] != null
          ? DateTime.parse(row['notified_at'] as String)
          : null,
      recurrenceGroupId: row['recurrence_group_id'] as String?,
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
    );
  }
}
