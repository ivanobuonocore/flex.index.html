import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/chat/presentation/chat_detail_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/workspace_chat_list_screen.dart';
import '../../features/document/presentation/document_list_screen.dart';
import '../../features/note/presentation/note_list_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/task/presentation/task_list_screen.dart';
import '../../features/today/presentation/today_screen.dart';
import '../../features/transaction/presentation/transaction_report_screen.dart';
import '../../features/workspace/presentation/workspace_detail_screen.dart';
import '../../features/workspace/presentation/workspace_list_screen.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(sessionControllerProvider, (_, __) => refreshNotifier.notify());
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/today',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      // In caricamento: nessun redirect, evita un flash sulla schermata di login
      // mentre la sessione iniziale viene ancora risolta.
      if (session.isLoading) return null;

      final isAuthenticated = session.value != null;
      final isOnAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuthenticated && !isOnAuthRoute) return '/login';
      if (isAuthenticated && isOnAuthRoute) return '/today';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/today',
                  builder: (context, state) => const TodayScreen())
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/chat',
                  builder: (context, state) => const ChatListScreen()),
            ],
          ),
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
                        path: 'chat',
                        builder: (context, state) => WorkspaceChatListScreen(
                          workspaceId: state.pathParameters['id']!,
                        ),
                        routes: [
                          GoRoute(
                            path: ':chatId',
                            builder: (context, state) => ChatDetailScreen(
                              chatId: state.pathParameters['chatId']!,
                              workspaceId: state.pathParameters['id']!,
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'transactions',
                        builder: (context, state) => TransactionReportScreen(
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
                  path: '/search',
                  builder: (context, state) => const SearchScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/profile',
                  builder: (context, state) => const ProfileScreen()),
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
