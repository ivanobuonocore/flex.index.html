import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Stato del collegamento a Google Calendar dell'utente corrente (`null` =
/// non collegato). `FutureProvider`, non uno `StreamProvider` come le altre
/// entità dell'app — vedi la doc di [CalendarSyncRepository.fetchConnectionStatus]
/// per il motivo. Va invalidato esplicitamente dopo `connect()`/`disconnect()`
/// perché non c'è un canale realtime che lo aggiorni da solo.
final calendarConnectionProvider =
    FutureProvider.autoDispose<CalendarConnection?>((ref) async {
  final result =
      await ref.watch(calendarSyncRepositoryProvider).fetchConnectionStatus();
  if (result.isErr) {
    throw (result as Err<CalendarConnection?>).failure;
  }
  return (result as Ok<CalendarConnection?>).value;
});

final calendarSyncFormControllerProvider =
    AsyncNotifierProvider.autoDispose<CalendarSyncFormController, void>(
        CalendarSyncFormController.new);

class CalendarSyncFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Failure?> connect() async {
    state = const AsyncLoading();
    final result =
        await ref.read(calendarSyncRepositoryProvider).beginConnect();
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  Future<Failure?> disconnect() async {
    state = const AsyncLoading();
    final result = await ref.read(calendarSyncRepositoryProvider).disconnect();
    state = const AsyncData(null);
    if (result.isOk) {
      ref.invalidate(calendarConnectionProvider);
    }
    return result.fold((_) => null, (failure) => failure);
  }
}
