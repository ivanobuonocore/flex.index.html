import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/task/application/task_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_task_repository.dart';

void main() {
  const workspaceId = 'w1';
  final task = Task(
    id: 't1',
    workspaceId: workspaceId,
    title: 'Scrivere report',
    status: TaskStatus.todo,
    priority: TaskPriority.medium,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  late FakeTaskRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeTaskRepository();
    container = ProviderContainer(
      overrides: [taskRepositoryProvider.overrideWithValue(fakeRepository)],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
  });

  test('tasksProvider riflette lo stream del repository per workspace',
      () async {
    final subscription =
        container.listen(tasksProvider(workspaceId), (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emit([task]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(tasksProvider(workspaceId)).value, [task]);
  });

  test('create con successo non ritorna errore', () async {
    fakeRepository.createResult = Result.ok(task);

    final failure = await container
        .read(taskFormControllerProvider.notifier)
        .create(workspaceId: workspaceId, title: 'Scrivere report');

    expect(failure, isNull);
    expect(fakeRepository.lastCreated, task);
  });

  test('updateTask (toggle stato) e delete delegano al repository', () async {
    final controller = container.read(taskFormControllerProvider.notifier);

    final done = task.copyWith(status: TaskStatus.done);
    await controller.updateTask(done);
    expect(fakeRepository.lastUpdated, done);

    await controller.delete(task.id);
    expect(fakeRepository.lastDeletedId, task.id);
  });

  group('openTasks', () {
    test('esclude le attività già completate', () {
      final todo = task.copyWith(status: TaskStatus.todo);
      final done = Task(
        id: 't2',
        workspaceId: workspaceId,
        title: 'Fatto ieri',
        status: TaskStatus.done,
        priority: TaskPriority.medium,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(openTasks([todo, done]), [todo]);
    });

    test('lista vuota se non ci sono attività aperte', () {
      final done = task.copyWith(status: TaskStatus.done);

      expect(openTasks([done]), isEmpty);
    });
  });
}
