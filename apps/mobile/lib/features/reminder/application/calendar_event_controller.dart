import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Promemoria di un Workspace, in tempo reale (Software Architecture,
/// "Sincronizzazione" — Realtime lato Supabase).
final calendarEventsProvider =
    StreamProvider.autoDispose.family<List<CalendarEvent>, String>(
  (ref, workspaceId) =>
      ref.watch(calendarEventRepositoryProvider).watchEvents(workspaceId),
);

final calendarEventFormControllerProvider =
    AsyncNotifierProvider.autoDispose<CalendarEventFormController, void>(
        CalendarEventFormController.new);

class CalendarEventFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Failure?> create({
    required String workspaceId,
    required String title,
    required DateTime startsAt,
    int durationMinutes = 30,
    int? reminderMinutesBefore,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(calendarEventRepositoryProvider).createEvent(
          workspaceId: workspaceId,
          title: title,
          startsAt: startsAt,
          durationMinutes: durationMinutes,
          reminderMinutesBefore: reminderMinutesBefore,
        );
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  Future<Failure?> delete(String eventId) async {
    state = const AsyncLoading();
    final result =
        await ref.read(calendarEventRepositoryProvider).deleteEvent(eventId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}
