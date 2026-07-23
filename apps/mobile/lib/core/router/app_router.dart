import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/chat/presentation/chat_home_screen.dart';
import '../../features/document/presentation/document_list_screen.dart';
import '../../features/memory/presentation/memory_list_screen.dart';
import '../../features/memory/presentation/workspace_memory_list_screen.dart';
import '../../features/note/presentation/note_list_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reminder/presentation/appointments_overview_screen.dart';
import '../../features/reminder/presentation/reminder_list_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/task/presentation/task_list_screen.dart';
import '../../features/transaction/presentation/balance_overview_screen.dart';
import '../../features/transaction/presentation/transaction_report_screen.dart';
import '../../features/workspace/presentation/shared_balance_screen.dart';
import '../../features/workspace/presentation/workspace_detail_screen.dart';
import '../../features/workspace/presentation/workspace_list_screen.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(sessionControllerProvider, (_, __) => refreshNotifier.notify());
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/chat',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      // In caricamento: nessun redirect, evita un flash sulla schermata di login
      // mentre la sessione iniziale viene ancora risolta.
      if (session.isLoading) return null;

      final user = session.value;
      final isOnAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isOnOnboardingRoute = state.matchedLocation == '/onboarding';

      if (user == null) return isOnAuthRoute ? null : '/login';

      // Onboarding leggero al primo accesso (richiesta esplicita
      // dell'utente): un gate in più tra il login e il resto dell'app,
      // finché `User.onboardingCompleted` non è vero — una volta completato
      // (o saltato) non ci si torna più.
      final needsOnboarding = !user.onboardingCompleted;
      if (needsOnboarding) return isOnOnboardingRoute ? null : '/onboarding';
      if (isOnAuthRoute || isOnOnboardingRoute) return '/chat';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen()),
      GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen()),
      // Ricerca Universale (richiesta esplicita dell'utente: tolta dalla
      // barra di navigazione, sostituita lì da Appuntamenti — resta
      // raggiungibile con un push da un'icona nell'intestazione della Chat
      // Home) — fuori dallo StatefulShellRoute apposta: non è una delle 5
      // destinazioni principali, ma una schermata "di passaggio" come
      // login/onboarding, aperta e poi chiusa con "indietro".
      GoRoute(
          path: '/search', builder: (context, state) => const SearchScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        // Ordine della barra di navigazione (redesign estetico — richiesta
        // esplicita dell'utente): Workspace, Bilancio, [Chat al centro, in
        // risalto], Appuntamenti, Profilo — Ricerca tolta da qui (richiesta
        // esplicita dell'utente), resta raggiungibile da un'icona in Chat
        // Home. L'ordine dei branch deve corrispondere 1:1 a quello delle
        // destinazioni in `AppShell` (indice per indice).
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workspace',
                builder: (context, state) => const WorkspaceListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => WorkspaceDetailScreen(
                      workspaceId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'notes',
                        builder: (context, state) => NoteListScreen(
                          workspaceId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'tasks',
                        builder: (context, state) => TaskListScreen(
                          workspaceId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'documents',
                        builder: (context, state) => DocumentListScreen(
                          workspaceId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'transactions',
                        builder: (context, state) => TransactionReportScreen(
                          workspaceId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'reminders',
                        builder: (context, state) => ReminderListScreen(
                          workspaceId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'memories',
                        builder: (context, state) => WorkspaceMemoryListScreen(
                          workspaceId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/balance',
                builder: (context, state) => const BalanceOverviewScreen(),
                routes: [
                  GoRoute(
                    path: 'shared',
                    builder: (context, state) => const SharedBalanceScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/appuntamenti',
                  builder: (context, state) =>
                      const AppointmentsOverviewScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'memories',
                    builder: (context, state) => const MemoryListScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
