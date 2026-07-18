import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../core/providers.dart';

/// Sessione corrente, derivata dallo stream di [AuthRepository]. La UI
/// (incluso il router) legge sempre questo stato, mai Supabase direttamente
/// (CLAUDE.md, "Mai collegare il frontend direttamente a un provider" — lo
/// stesso principio si applica all'identity provider).
final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, User?>(
  SessionController.new,
);

class SessionController extends AsyncNotifier<User?> {
  StreamSubscription<User?>? _subscription;

  @override
  Future<User?> build() {
    final repository = ref.watch(authRepositoryProvider);
    final completer = Completer<User?>();
    var isFirstEvent = true;

    _subscription?.cancel();
    _subscription = repository.watchCurrentUser().listen(
      (user) {
        if (isFirstEvent) {
          isFirstEvent = false;
          completer.complete(user);
        } else {
          state = AsyncData(user);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (isFirstEvent) {
          isFirstEvent = false;
          completer.completeError(error, stackTrace);
        } else {
          state = AsyncError(error, stackTrace);
        }
      },
    );

    ref.onDispose(() => _subscription?.cancel());
    return completer.future;
  }
}
