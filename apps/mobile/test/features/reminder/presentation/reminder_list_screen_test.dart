import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/reminder/presentation/reminder_list_screen.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_calendar_event_repository.dart';

/// Fase 3, "Promemoria via Chat" — richiesta esplicita dell'utente di
/// notifiche push vere: qui verifichiamo solo la gestione manuale (lista,
/// creazione, eliminazione), l'invio della notifica è responsabilità della
/// Edge Function send-due-reminders (non testabile in questo ambiente).
void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeCalendarEventRepository fakeRepository,
  ) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarEventRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: const MaterialApp(
          home: ReminderListScreen(workspaceId: 'w1'),
        ),
      ),
    );
  }

  testWidgets('mostra lo stato vuoto quando non ci sono promemoria',
      (tester) async {
    final fakeRepository = FakeCalendarEventRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit(const []);
    await tester.pumpAndSettle();

    expect(find.text('Nessun promemoria ancora'), findsOneWidget);
  });

  testWidgets('mostra i promemoria futuri nella lista', (tester) async {
    final fakeRepository = FakeCalendarEventRepository();
    addTearDown(fakeRepository.dispose);

    final event = CalendarEvent(
      id: 'e1',
      workspaceId: 'w1',
      title: 'Dentista',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      durationMinutes: 30,
      createdAt: DateTime.now(),
    );

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([event]);
    await tester.pumpAndSettle();

    expect(find.text('Dentista'), findsOneWidget);
  });

  testWidgets('crea un nuovo promemoria dal pulsante +', (tester) async {
    final fakeRepository = FakeCalendarEventRepository();
    addTearDown(fakeRepository.dispose);

    final created = CalendarEvent(
      id: 'e1',
      workspaceId: 'w1',
      title: 'Dentista',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      durationMinutes: 30,
      createdAt: DateTime.now(),
    );
    fakeRepository.createResult = Result.ok(created);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit(const []);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Dentista');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Crea promemoria'));
    await tester.pumpAndSettle();

    expect(fakeRepository.lastCreated?.title, 'Dentista');
  });

  testWidgets('eliminare un promemoria con lo swipe delega al repository',
      (tester) async {
    final fakeRepository = FakeCalendarEventRepository();
    addTearDown(fakeRepository.dispose);

    final event = CalendarEvent(
      id: 'e1',
      workspaceId: 'w1',
      title: 'Dentista',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      durationMinutes: 30,
      createdAt: DateTime.now(),
    );

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([event]);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Dentista'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(fakeRepository.lastDeletedId, 'e1');
  });
}
