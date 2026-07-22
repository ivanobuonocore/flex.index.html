/// Modello di dominio PIP (docs/product/12-domain-model.md).
///
/// Nessun file di questa libreria importa Flutter, Supabase o pacchetti di un
/// provider AI: le dipendenze puntano verso il centro (Engineering
/// Constitution, Articolo 4).
library pip_domain;

export 'src/enums.dart';
export 'src/shared_balance_category.dart';
export 'src/system_workspace_category.dart';

export 'src/entities/agent.dart';
export 'src/entities/calendar_event.dart';
export 'src/entities/category_budget.dart';
export 'src/entities/chat.dart';
export 'src/entities/document.dart';
export 'src/entities/memory.dart';
export 'src/entities/message.dart';
export 'src/entities/note.dart';
export 'src/entities/search_result.dart';
export 'src/entities/task.dart';
export 'src/entities/timeline_event.dart';
export 'src/entities/transaction.dart';
export 'src/entities/user.dart';
export 'src/entities/workspace.dart';
export 'src/entities/workspace_invite.dart';
export 'src/entities/workspace_member.dart';

export 'src/repositories/auth_repository.dart';
export 'src/repositories/budget_repository.dart';
export 'src/repositories/calendar_event_repository.dart';
export 'src/repositories/chat_repository.dart';
export 'src/repositories/document_repository.dart';
export 'src/repositories/memory_repository.dart';
export 'src/repositories/message_repository.dart';
export 'src/repositories/note_repository.dart';
export 'src/repositories/push_subscription_repository.dart';
export 'src/repositories/search_repository.dart';
export 'src/repositories/task_repository.dart';
export 'src/repositories/transaction_repository.dart';
export 'src/repositories/workspace_repository.dart';
export 'src/repositories/workspace_sharing_repository.dart';
