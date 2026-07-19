import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Task', () {
    test('copyWith aggiorna solo i campi indicati', () {
      final task = Task(
        id: 't1',
        workspaceId: 'w1',
        title: 'Scrivere report',
        status: TaskStatus.todo,
        priority: TaskPriority.medium,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final completed = task.copyWith(status: TaskStatus.done);

      expect(completed.status, TaskStatus.done);
      expect(completed.title, task.title);
      expect(completed.priority, task.priority);
      expect(completed.id, task.id);
    });
  });
}
