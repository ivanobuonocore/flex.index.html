import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  group('CalendarConnection', () {
    final createdAt = DateTime.utc(2026, 7, 20);

    test('lastSyncedAt di default è null (mai sincronizzato)', () {
      final connection = CalendarConnection(
        googleCalendarId: 'primary',
        createdAt: createdAt,
      );

      expect(connection.lastSyncedAt, isNull);
    });

    test('lastSyncedAt diverso distingue due connessioni altrimenti identiche',
        () {
      final justSynced = CalendarConnection(
        googleCalendarId: 'primary',
        createdAt: createdAt,
        lastSyncedAt: DateTime.utc(2026, 7, 22, 10),
      );
      final neverSynced = CalendarConnection(
        googleCalendarId: 'primary',
        createdAt: createdAt,
      );

      expect(justSynced, isNot(equals(neverSynced)));
    });

    test('due connessioni con gli stessi campi sono uguali per valore', () {
      final a = CalendarConnection(
        googleCalendarId: 'primary',
        createdAt: createdAt,
      );
      final b = CalendarConnection(
        googleCalendarId: 'primary',
        createdAt: createdAt,
      );

      expect(a, equals(b));
    });
  });
}
