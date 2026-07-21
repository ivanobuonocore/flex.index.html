import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeMemoryRepository implements MemoryRepository {
  FakeMemoryRepository({this.deleteResult});

  final _controller = StreamController<List<Memory>>.broadcast();
  Result<Unit>? deleteResult;
  String? lastDeletedId;

  void emit(List<Memory> memories) => _controller.add(memories);

  @override
  Stream<List<Memory>> watchGlobalMemories() => _controller.stream;

  @override
  Future<Result<Unit>> deleteMemory(String memoryId) async {
    lastDeletedId = memoryId;
    return deleteResult ?? const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
