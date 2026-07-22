import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeMemoryRepository implements MemoryRepository {
  FakeMemoryRepository({this.deleteResult, this.createWorkspaceResult});

  final _globalController = StreamController<List<Memory>>.broadcast();
  final _workspaceController = StreamController<List<Memory>>.broadcast();
  Result<Unit>? deleteResult;
  Result<Memory>? createWorkspaceResult;
  String? lastDeletedId;
  String? lastCreatedWorkspaceId;
  String? lastCreatedContent;

  void emit(List<Memory> memories) => _globalController.add(memories);
  void emitWorkspace(List<Memory> memories) =>
      _workspaceController.add(memories);

  @override
  Stream<List<Memory>> watchGlobalMemories() => _globalController.stream;

  @override
  Stream<List<Memory>> watchWorkspaceMemories(String workspaceId) =>
      _workspaceController.stream;

  @override
  Future<Result<Memory>> createWorkspaceMemory({
    required String workspaceId,
    required String content,
  }) async {
    lastCreatedWorkspaceId = workspaceId;
    lastCreatedContent = content;
    return createWorkspaceResult ??
        const Result<Memory>.err(
            ValidationFailure('Nessun risultato configurato.'));
  }

  @override
  Future<Result<Unit>> deleteMemory(String memoryId) async {
    lastDeletedId = memoryId;
    return deleteResult ?? const Result.ok(unit);
  }

  void dispose() {
    _globalController.close();
    _workspaceController.close();
  }
}
