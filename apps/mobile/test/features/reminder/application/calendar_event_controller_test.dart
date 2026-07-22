import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/reminder/application/calendar_event_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_calendar_event_repository.dart';

void main() {
  final event = CalendarEvent(
    id: 'e1',
    workspaceId: 'w1',
    title: 'Dentista',
    startsAt: DateTime.utc(2026, 1, 10, 15),
    durationMinutes: 30,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  late FakeCalendarEventRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeCalendarEventRepository();
    container = ProviderContainer(
      overrides: [
        calendarEventRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
  });

  test('calendarEventsProvider riflette lo stream del repository per workspace',
      () async {
    final subscription =
        container.listen(calendarEventsProvider('w1'), (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emit([event]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(calendarEventsProvider('w1')).value, [event]);
  });

  test('create con successo non ritorna errore', () async {
    fakeRepository.createResult = Result.ok(event);

    final failure = await container
        .read(calendarEventFormControllerProvider.notifier)
        .create(
          workspaceId: 'w1',
          title: 'Dentista',
          startsAt: DateTime.utc(2026, 1, 10, 15),
        );

    expect(failure, isNull);
    expect(fakeRepository.lastCreated, event);
  });

  test('create con titolo vuoto ritorna un ValidationFailure', () async {
    fakeRepository.createResult = const Result.err(
        ValidationFailure('Il titolo del promemoria è obbligatorio.'));

    final failure = await container
        .read(calendarEventFormControllerProvider.notifier)
        .create(
          workspaceId: 'w1',
          title: '',
          startsAt: DateTime.utc(2026, 1, 10, 15),
        );

    expect(failure, isA<ValidationFailure>());
  });

  test('delete delega al repository', () async {
    final failure = await container
        .read(calendarEventFormControllerProvider.notifier)
        .delete('e1');

    expect(failure, isNull);
    expect(fakeRepository.lastDeletedId, 'e1');
  });

  test('deleteSeries delega al repository con il recurrenceGroupId', () async {
    final failure = await container
        .read(calendarEventFormControllerProvider.notifier)
        .deleteSeries('rg1');

    expect(failure, isNull);
    expect(fakeRepository.lastDeletedRecurrenceGroupId, 'rg1');
  });
}
