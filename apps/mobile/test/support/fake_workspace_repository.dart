import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeWorkspaceRepository implements WorkspaceRepository {
  FakeWorkspaceRepository({this.createResult});

  final _controller = StreamController<List<Workspace>>.broadcast();
  Result<Workspace>? createResult;
  Result<Workspace>? updateResult;
  Result<Unit>? archiveResult;
  Workspace? lastCreated;
  Workspace? lastUpdated;
  String? lastArchivedId;
  final List<String> createdCategories = [];

  void emit(List<Workspace> workspaces) => _controller.add(workspaces);

  @override
  Stream<List<Workspace>> watchWorkspaces() => _controller.stream;

  @override
  Future<Result<Workspace>> createWorkspace({
    required String name,
    required String icon,
    String? description,
    String? category,
    String? color,
  }) async {
    if (category != null) createdCategories.add(category);
    final result = createResult ??
        const Result<Workspace>.err(
            ValidationFailure('Nessun risultato configurato.'));
    if (result.isOk) {
      lastCreated = (result as Ok<Workspace>).value;
    }
    return result;
  }

  @override
  Future<Result<Workspace>> updateWorkspace(Workspace workspace) async {
    lastUpdated = workspace;
    return updateResult ?? Result.ok(workspace);
  }

  @override
  Future<Result<Unit>> archiveWorkspace(String workspaceId) async {
    lastArchivedId = workspaceId;
    return archiveResult ?? const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
