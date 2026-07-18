import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Workspace', () {
    test('copyWith preserva id, ownerId e createdAt', () {
      final workspace = Workspace(
        id: 'w1',
        ownerId: 'u1',
        name: 'Lavoro',
        icon: 'briefcase',
        status: WorkspaceStatus.active,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final archived = workspace.copyWith(status: WorkspaceStatus.archived);

      expect(archived.status, WorkspaceStatus.archived);
      expect(archived.id, 'w1');
      expect(archived.ownerId, 'u1');
      expect(archived.createdAt, workspace.createdAt);
    });
  });
}
