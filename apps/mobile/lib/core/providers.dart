import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../features/auth/data/supabase_auth_repository.dart';
import '../features/chat/data/supabase_chat_repository.dart';
import '../features/chat/data/supabase_message_repository.dart';
import '../features/document/data/supabase_document_repository.dart';
import '../features/note/data/supabase_note_repository.dart';
import '../features/notifications/data/supabase_push_subscription_repository.dart';
import '../features/reminder/data/supabase_calendar_event_repository.dart';
import '../features/search/data/supabase_search_repository.dart';
import '../features/task/data/supabase_task_repository.dart';
import '../features/transaction/data/supabase_transaction_repository.dart';
import '../features/workspace/data/supabase_workspace_repository.dart';
import '../features/workspace/data/supabase_workspace_sharing_repository.dart';
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

final workspaceSharingRepositoryProvider =
    Provider<WorkspaceSharingRepository>((ref) {
  return SupabaseWorkspaceSharingRepository(ref.watch(supabaseClientProvider));
});

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return SupabaseNoteRepository(ref.watch(supabaseClientProvider));
});

final calendarEventRepositoryProvider =
    Provider<CalendarEventRepository>((ref) {
  return SupabaseCalendarEventRepository(ref.watch(supabaseClientProvider));
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return SupabaseTaskRepository(ref.watch(supabaseClientProvider));
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return SupabaseDocumentRepository(ref.watch(supabaseClientProvider));
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SupabaseSearchRepository(ref.watch(supabaseClientProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return SupabaseChatRepository(ref.watch(supabaseClientProvider));
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return SupabaseMessageRepository(ref.watch(supabaseClientProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return SupabaseTransactionRepository(ref.watch(supabaseClientProvider));
});

final pushSubscriptionRepositoryProvider =
    Provider<PushSubscriptionRepository>((ref) {
  return SupabasePushSubscriptionRepository(ref.watch(supabaseClientProvider));
});
