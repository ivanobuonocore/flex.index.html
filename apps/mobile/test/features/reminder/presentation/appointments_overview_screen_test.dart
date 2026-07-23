import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/reminder/presentation/appointments_overview_screen.dart';

import '../../../support/fake_calendar_event_repository.dart';
import '../../../support/fake_workspace_repository.dart';

/// Appuntamenti globale (quarta voce della barra di navigazione, al posto
/// della Ricerca — richiesta esplicita dell'utente): a differenza di
/// ReminderListScreen aggrega i promemoria di **tutti** i Workspace
/// dell'utente, `calendarEventsProvider(null)`.
void main() {
  final workspaceA = Workspace(
    id: 'w1',
    ownerId: 'u1',
    name: 'Lavoro',
    icon: 'briefcase',
    status: WorkspaceStatus.active,
    createdAt: DateTime.utc(2026, 1, 1),
  );
  final workspaceB = Workspace(
    id: 'w2',
    ownerId: 'u1',
    name: 'Personale',
    icon: 'home',
    status: WorkspaceStatus.active,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required FakeCalendarEventRepository fakeEvents,
    required FakeWorkspaceRepository fakeWorkspaces,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarEventRepositoryProvider.overrideWithValue(fakeEvents),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspaces),
        ],
        child: const MaterialApp(home: AppointmentsOverviewScreen()),
      ),
    );
  }

  testWidgets('mostra lo stato vuoto quando non ci sono appuntamenti',
      (tester) async {
    final fakeEvents = FakeCalendarEventRepository();
    final fakeWorkspaces = FakeWorkspaceRepository();
    addTearDown(fakeEvents.dispose);
    addTearDown(fakeWorkspaces.dispose);

    await pumpScreen(tester,
        fakeEvents: fakeEvents, fakeWorkspaces: fakeWorkspaces);
    fakeEvents.emit(const []);
    fakeWorkspaces.emit([workspaceA]);
    await tester.pumpAndSettle();

    expect(find.text('Nessun appuntamento ancora'), findsOneWidget);
  });

  testWidgets(
      'aggrega i promemoria di più Workspace e mostra il nome del Workspace di origine',
      (tester) async {
    final fakeEvents = FakeCalendarEventRepository();
    final fakeWorkspaces = FakeWorkspaceRepository();
    addTearDown(fakeEvents.dispose);
    addTearDown(fakeWorkspaces.dispose);

    final eventA = CalendarEvent(
      id: 'e1',
      workspaceId: 'w1',
      title: 'Riunione',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      durationMinutes: 30,
      createdAt: DateTime.now(),
    );
    final eventB = CalendarEvent(
      id: 'e2',
      workspaceId: 'w2',
      title: 'Dentista',
      startsAt: DateTime.now().add(const Duration(days: 2)),
      durationMinutes: 30,
      createdAt: DateTime.now(),
    );

    await pumpScreen(tester,
        fakeEvents: fakeEvents, fakeWorkspaces: fakeWorkspaces);
    fakeWorkspaces.emit([workspaceA, workspaceB]);
    fakeEvents.emit([eventA, eventB]);
    await tester.pumpAndSettle();

    expect(find.text('Riunione'), findsOneWidget);
    expect(find.text('Dentista'), findsOneWidget);
    expect(find.textContaining('Lavoro'), findsOneWidget);
    expect(find.textContaining('Personale'), findsOneWidget);
  });

  testWidgets(
      'toccare un appuntamento apre i Promemoria del suo Workspace di origine',
      (tester) async {
    final fakeEvents = FakeCalendarEventRepository();
    final fakeWorkspaces = FakeWorkspaceRepository();
    addTearDown(fakeEvents.dispose);
    addTearDown(fakeWorkspaces.dispose);

    final event = CalendarEvent(
      id: 'e1',
      workspaceId: 'w1',
      title: 'Riunione',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      durationMinutes: 30,
      createdAt: DateTime.now(),
    );

    String? matchedRoute;
    final router = GoRouter(
      initialLocation: '/appuntamenti',
      routes: [
        GoRoute(
          path: '/appuntamenti',
          builder: (context, state) => const AppointmentsOverviewScreen(),
        ),
        GoRoute(
          path: '/workspace/:id/reminders',
          builder: (context, state) {
            matchedRoute = '/workspace/${state.pathParameters['id']}/reminders';
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarEventRepositoryProvider.overrideWithValue(fakeEvents),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspaces),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    fakeWorkspaces.emit([workspaceA]);
    fakeEvents.emit([event]);
    await tester.pumpAndSettle();

    // Il calendario (GridView) e l'elenco sotto (ListView) hanno ciascuno
    // il proprio Scrollable interno, oltre a quello esterno: il finder va
    // ristretto a quello esterno per restare univoco.
    await tester.scrollUntilVisible(find.text('Riunione'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Riunione'));
    await tester.pumpAndSettle();

    expect(matchedRoute, '/workspace/w1/reminders');
  });

  testWidgets('nessun FAB: la creazione resta per Workspace o via Chat',
      (tester) async {
    final fakeEvents = FakeCalendarEventRepository();
    final fakeWorkspaces = FakeWorkspaceRepository();
    addTearDown(fakeEvents.dispose);
    addTearDown(fakeWorkspaces.dispose);

    await pumpScreen(tester,
        fakeEvents: fakeEvents, fakeWorkspaces: fakeWorkspaces);
    fakeEvents.emit(const []);
    fakeWorkspaces.emit([workspaceA]);
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
