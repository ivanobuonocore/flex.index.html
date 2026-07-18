import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../features/auth/data/supabase_auth_repository.dart';
import '../features/workspace/data/supabase_workspace_repository.dart';
import 'supabase/supabase_bootstrap.dart';

/// Confini concreti (Supabase) dietro le interfacce di dominio, unico punto
/// in cui l'app collega `data` a `domain` (Dependency Inversion).
final supabaseClientProvider =
    Provider<supabase.SupabaseClient>((ref) => supabaseClient);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  return SupabaseWorkspaceRepository(ref.watch(supabaseClientProvider));
});
