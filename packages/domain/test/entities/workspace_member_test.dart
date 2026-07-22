import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  group('WorkspaceMember', () {
    test('role ha come default WorkspaceRole.editor', () {
      final member = WorkspaceMember(
        id: 'm1',
        workspaceId: 'w1',
        userId: 'u1',
        joinedAt: DateTime.utc(2026, 1, 1),
      );

      expect(member.role, WorkspaceRole.editor);
    });

    test('ruolo diverso distingue due membri altrimenti identici', () {
      WorkspaceMember withRole(WorkspaceRole role) => WorkspaceMember(
            id: 'm1',
            workspaceId: 'w1',
            userId: 'u1',
            joinedAt: DateTime.utc(2026, 1, 1),
            role: role,
          );

      expect(
        withRole(WorkspaceRole.viewer) == withRole(WorkspaceRole.editor),
        isFalse,
      );
      expect(withRole(WorkspaceRole.viewer), withRole(WorkspaceRole.viewer));
    });
  });
}
