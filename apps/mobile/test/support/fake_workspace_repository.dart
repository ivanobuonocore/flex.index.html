import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeWorkspaceRepository implements WorkspaceRepository {
  FakeWorkspaceRepository({this.createResult});

  final _controller = StreamController<List<Workspace>>.broadcast();
  Result<Workspace>? createResult;
  Workspace? lastCreated;

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
    return Result.ok(workspace);
  }

  @override
  Future<Result<Unit>> archiveWorkspace(String workspaceId) async {
    return const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
