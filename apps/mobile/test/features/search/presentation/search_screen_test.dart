import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/search/presentation/search_screen.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_search_repository.dart';

/// Ricerca Universale estesa a Transazioni confermate e Promemoria
/// (richiesta esplicita dell'utente) — qui si verifica solo icona/etichetta
/// e il routing dei due nuovi tipi, non il round-trip col database (già
/// verificato su Postgres locale per `search_workspace_content`).
void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeSearchRepository fakeRepository, {
    required ValueChanged<String> onRouteMatched,
  }) {
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/workspace/:id/transactions',
          builder: (context, state) {
            onRouteMatched(
                '/workspace/${state.pathParameters['id']}/transactions');
            return const SizedBox.shrink();
          },
        ),
        GoRoute(
          path: '/workspace/:id/reminders',
          builder: (context, state) {
            onRouteMatched(
                '/workspace/${state.pathParameters['id']}/reminders');
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('mostra icona ed etichetta per Transazione e Promemoria',
      (tester) async {
    final fakeRepository = FakeSearchRepository(
      result: const Result.ok([
        SearchResult(
          type: SearchResultType.transaction,
          id: 't1',
          workspaceId: 'w1',
          title: 'Barbiere',
          snippet: '-23,00 €',
        ),
        SearchResult(
          type: SearchResultType.reminder,
          id: 'r1',
          workspaceId: 'w1',
          title: 'Dal dentista',
        ),
      ]),
    );

    await pumpScreen(tester, fakeRepository, onRouteMatched: (_) {});
    await tester.enterText(find.byType(TextField), 'barbiere');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Barbiere'), findsOneWidget);
    expect(find.text('Dal dentista'), findsOneWidget);
    expect(find.text('Promemoria'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });

  testWidgets(
      'toccare un risultato Transazione naviga a /workspace/:id/transactions',
      (tester) async {
    final fakeRepository = FakeSearchRepository(
      result: const Result.ok([
        SearchResult(
          type: SearchResultType.transaction,
          id: 't1',
          workspaceId: 'w1',
          title: 'Barbiere',
        ),
      ]),
    );

    String? matchedRoute;
    await pumpScreen(tester, fakeRepository,
        onRouteMatched: (route) => matchedRoute = route);
    await tester.enterText(find.byType(TextField), 'barbiere');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Barbiere'));
    await tester.pumpAndSettle();

    expect(matchedRoute, '/workspace/w1/transactions');
  });

  testWidgets(
      'toccare un risultato Promemoria naviga a /workspace/:id/reminders',
      (tester) async {
    final fakeRepository = FakeSearchRepository(
      result: const Result.ok([
        SearchResult(
          type: SearchResultType.reminder,
          id: 'r1',
          workspaceId: 'w1',
          title: 'Dal dentista',
        ),
      ]),
    );

    String? matchedRoute;
    await pumpScreen(tester, fakeRepository,
        onRouteMatched: (route) => matchedRoute = route);
    await tester.enterText(find.byType(TextField), 'dentista');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dal dentista'));
    await tester.pumpAndSettle();

    expect(matchedRoute, '/workspace/w1/reminders');
  });
}
