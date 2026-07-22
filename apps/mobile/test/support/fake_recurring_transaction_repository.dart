import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeRecurringTransactionRepository
    implements RecurringTransactionRepository {
  FakeRecurringTransactionRepository({this.deleteResult});

  final _controller =
      StreamController<List<RecurringTransactionTemplate>>.broadcast();
  Result<Unit>? deleteResult;
  String? lastDeletedId;

  void emit(List<RecurringTransactionTemplate> templates) =>
      _controller.add(templates);

  @override
  Stream<List<RecurringTransactionTemplate>> watchTemplates(
    String workspaceId,
  ) =>
      _controller.stream;

  @override
  Future<Result<Unit>> deleteTemplate(String templateId) async {
    lastDeletedId = templateId;
    return deleteResult ?? const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
