import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  group('WorkspaceInvite', () {
    test('role ha come default WorkspaceRole.editor', () {
      final invite = WorkspaceInvite(
        id: 'i1',
        workspaceId: 'w1',
        code: 'ABCD1234',
        createdBy: 'u1',
        createdAt: DateTime.utc(2026, 1, 1),
        expiresAt: DateTime.utc(2026, 1, 8),
      );

      expect(invite.role, WorkspaceRole.editor);
    });

    test('ruolo diverso distingue due inviti altrimenti identici', () {
      WorkspaceInvite withRole(WorkspaceRole role) => WorkspaceInvite(
            id: 'i1',
            workspaceId: 'w1',
            code: 'ABCD1234',
            createdBy: 'u1',
            createdAt: DateTime.utc(2026, 1, 1),
            expiresAt: DateTime.utc(2026, 1, 8),
            role: role,
          );

      expect(
        withRole(WorkspaceRole.viewer) == withRole(WorkspaceRole.editor),
        isFalse,
      );
      expect(withRole(WorkspaceRole.viewer), withRole(WorkspaceRole.viewer));
    });

    test('isExpired confronta expiresAt con il riferimento indicato', () {
      final invite = WorkspaceInvite(
        id: 'i1',
        workspaceId: 'w1',
        code: 'ABCD1234',
        createdBy: 'u1',
        createdAt: DateTime.utc(2026, 1, 1),
        expiresAt: DateTime.utc(2026, 1, 8),
      );

      expect(invite.isExpired(now: DateTime.utc(2026, 1, 9)), isTrue);
      expect(invite.isExpired(now: DateTime.utc(2026, 1, 7)), isFalse);
    });
  });
}
