import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  group('CalendarEvent', () {
    final startsAt = DateTime.utc(2026, 7, 27, 9);
    final createdAt = DateTime.utc(2026, 7, 20);

    test('recurrenceGroupId di default è null (promemoria singolo)', () {
      final event = CalendarEvent(
        id: 'e1',
        workspaceId: 'w1',
        title: 'Dentista',
        startsAt: startsAt,
        durationMinutes: 30,
        createdAt: createdAt,
      );

      expect(event.recurrenceGroupId, isNull);
    });

    test(
        'due occorrenze con lo stesso recurrenceGroupId sono distinte solo per id/data',
        () {
      final first = CalendarEvent(
        id: 'e1',
        workspaceId: 'w1',
        title: 'Buttare la spazzatura',
        startsAt: startsAt,
        durationMinutes: 30,
        createdAt: createdAt,
        recurrenceGroupId: 'group-1',
      );
      final second = CalendarEvent(
        id: 'e2',
        workspaceId: 'w1',
        title: 'Buttare la spazzatura',
        startsAt: startsAt.add(const Duration(days: 7)),
        durationMinutes: 30,
        createdAt: createdAt,
        recurrenceGroupId: 'group-1',
      );

      expect(first.recurrenceGroupId, second.recurrenceGroupId);
      expect(first, isNot(equals(second)));
    });

    test('recurrenceGroupId diverso distingue due eventi altrimenti identici',
        () {
      final withGroup = CalendarEvent(
        id: 'e1',
        workspaceId: 'w1',
        title: 'Dentista',
        startsAt: startsAt,
        durationMinutes: 30,
        createdAt: createdAt,
        recurrenceGroupId: 'group-1',
      );
      final withoutGroup = CalendarEvent(
        id: 'e1',
        workspaceId: 'w1',
        title: 'Dentista',
        startsAt: startsAt,
        durationMinutes: 30,
        createdAt: createdAt,
      );

      expect(withGroup, isNot(equals(withoutGroup)));
    });
  });
}
