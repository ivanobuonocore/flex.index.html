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

  testWidgets(
      'un promemoria con recurrenceGroupId mostra il badge "ricorrente"',
      (tester) async {
    final fakeRepository = FakeCalendarEventRepository();
    addTearDown(fakeRepository.dispose);

    final recurring = CalendarEvent(
      id: 'e1',
      workspaceId: 'w1',
      title: 'Buttare la spazzatura',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      durationMinutes: 30,
      createdAt: DateTime.now(),
      recurrenceGroupId: 'group-1',
    );
    final single = CalendarEvent(
      id: 'e2',
      workspaceId: 'w1',
      title: 'Dentista',
      startsAt: DateTime.now().add(const Duration(days: 2)),
      durationMinutes: 30,
      createdAt: DateTime.now(),
    );

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([recurring, single]);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.repeat), findsOneWidget);
  });

  testWidgets(
      'selezionare un giorno nel calendario filtra l\'elenco a quel giorno',
      (tester) async {
    final fakeRepository = FakeCalendarEventRepository();
    addTearDown(fakeRepository.dispose);

    final now = DateTime.now();
    // Un secondo giorno nello stesso mese di "oggi", per non dover cambiare
    // mese nel calendario durante il test.
    final otherDay = now.day <= 15 ? now.day + 10 : now.day - 10;

    final eventToday = CalendarEvent(
      id: 'e-today',
      workspaceId: 'w1',
      title: 'Dentista',
      startsAt: DateTime(now.year, now.month, now.day, 10),
      durationMinutes: 30,
      createdAt: now,
    );
    final eventOtherDay = CalendarEvent(
      id: 'e-other',
      workspaceId: 'w1',
      title: 'Barbiere',
      startsAt: DateTime(now.year, now.month, otherDay, 9),
      durationMinutes: 30,
      createdAt: now,
    );

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([eventToday, eventOtherDay]);
    await tester.pumpAndSettle();

    // Senza alcun giorno selezionato, l'elenco resta quello completo.
    expect(find.text('Dentista'), findsOneWidget);
    expect(find.text('Barbiere'), findsOneWidget);

    // Tocca il giorno di "Barbiere" nel calendario: l'elenco si filtra a
    // quel solo giorno (richiesta esplicita dell'utente: "su ogni giorno
    // viene riportato l'appuntamento").
    await tester.tap(find.text('$otherDay'));
    await tester.pumpAndSettle();

    expect(find.text('Barbiere'), findsOneWidget);
    expect(find.text('Dentista'), findsNothing);

    // Toccando di nuovo lo stesso giorno il filtro si toglie.
    await tester.tap(find.text('$otherDay'));
    await tester.pumpAndSettle();

    expect(find.text('Dentista'), findsOneWidget);
    expect(find.text('Barbiere'), findsOneWidget);
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

    // Il calendario mensile in testa spinge l'elenco sotto la piega: va
    // scorso per portare la riga nella viewport prima di poterci fare lo
    // swipe, come farebbe l'utente.
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Dentista'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // "Annulla su eliminazioni" (integrazione richiesta esplicitamente): la
    // cancellazione reale è posticipata (SnackBar con azione "Annulla"), non
    // immediata — serve un pump esplicito più lungo del ritardo di default
    // (una `Timer` pura non fa fermare `pumpAndSettle()` ad aspettarla).
    await tester.pump(const Duration(seconds: 5));

    expect(fakeRepository.lastDeletedId, 'e1');
  });

  testWidgets(
      'toccare "Annulla" nello SnackBar dopo lo swipe ripristina il promemoria senza cancellarlo',
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

    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Dentista'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Dentista'), findsNothing);
    expect(fakeRepository.lastDeletedId, isNull);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 5));
    expect(fakeRepository.lastDeletedId, isNull);
    expect(find.text('Dentista'), findsOneWidget);
  });

  testWidgets(
      'eliminare con lo swipe un promemoria ricorrente chiede prima quale ambito',
      (tester) async {
    final fakeRepository = FakeCalendarEventRepository();
    addTearDown(fakeRepository.dispose);

    final event = CalendarEvent(
      id: 'e1',
      workspaceId: 'w1',
      title: 'Buttare la spazzatura',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      durationMinutes: 30,
      createdAt: DateTime.now(),
      recurrenceGroupId: 'group-1',
    );

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([event]);
    await tester.pumpAndSettle();

    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    await tester.drag(
        find.text('Buttare la spazzatura'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Promemoria ricorrente'), findsOneWidget);
    expect(fakeRepository.lastDeletedId, isNull);
    expect(fakeRepository.lastDeletedRecurrenceGroupId, isNull);

    await tester.tap(find.text('Intera serie'));
    await tester.pumpAndSettle();

    expect(fakeRepository.lastDeletedRecurrenceGroupId, 'group-1');
    expect(fakeRepository.lastDeletedId, isNull);
  });

  testWidgets(
      'un promemoria creato dalla Chat mostra l\'icona "creato dalla Chat" '
      '(Knowledge Graph "lite")', (tester) async {
    final fakeRepository = FakeCalendarEventRepository();
    addTearDown(fakeRepository.dispose);

    final fromChat = CalendarEvent(
      id: 'e1',
      workspaceId: 'w1',
      title: 'Dentista',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      durationMinutes: 30,
      createdAt: DateTime.now(),
      sourceChatId: 'chat-1',
    );
    final manual = CalendarEvent(
      id: 'e2',
      workspaceId: 'w1',
      title: 'Barbiere',
      startsAt: DateTime.now().add(const Duration(days: 2)),
      durationMinutes: 30,
      createdAt: DateTime.now(),
    );

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([fromChat, manual]);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
  });

  testWidgets(
      'annullare la scelta su un promemoria ricorrente non elimina nulla',
      (tester) async {
    final fakeRepository = FakeCalendarEventRepository();
    addTearDown(fakeRepository.dispose);

    final event = CalendarEvent(
      id: 'e1',
      workspaceId: 'w1',
      title: 'Buttare la spazzatura',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      durationMinutes: 30,
      createdAt: DateTime.now(),
      recurrenceGroupId: 'group-1',
    );

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([event]);
    await tester.pumpAndSettle();

    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    await tester.drag(
        find.text('Buttare la spazzatura'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(fakeRepository.lastDeletedId, isNull);
    expect(fakeRepository.lastDeletedRecurrenceGroupId, isNull);
    expect(find.text('Buttare la spazzatura'), findsOneWidget);
  });
}
