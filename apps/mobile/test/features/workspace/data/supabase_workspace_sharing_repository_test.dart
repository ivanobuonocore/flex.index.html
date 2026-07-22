import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/features/workspace/data/supabase_workspace_sharing_repository.dart';

/// `parseWorkspaceMemberRow`/`parseWorkspaceInviteRow`/`workspaceRoleFromDb`
/// sono la parte con logica reale di `watchMembers`/`createInvite`: separate
/// in funzioni pure proprio per poterle testare senza mockare il client
/// Supabase (stesso motivo di `parseMessageRow` in
/// `supabase_message_repository.dart`).
void main() {
  group('workspaceRoleFromDb', () {
    test('converte "viewer"/"editor" nel ruolo corrispondente', () {
      expect(workspaceRoleFromDb('viewer'), WorkspaceRole.viewer);
      expect(workspaceRoleFromDb('editor'), WorkspaceRole.editor);
    });

    test(
        'null (colonna aggiunta da una migrazione non ancora pushata) '
        'ricade su editor invece di fallire', () {
      expect(workspaceRoleFromDb(null), WorkspaceRole.editor);
    });
  });

  group('parseWorkspaceMemberRow', () {
    Map<String, dynamic> baseRow({Object? role = 'viewer'}) => {
          'id': 'member-1',
          'workspace_id': 'ws-1',
          'user_id': 'user-1',
          'joined_at': '2026-07-22T10:00:00.000Z',
          'role': role,
        };

    test('converte una riga completa in un WorkspaceMember', () {
      final member = parseWorkspaceMemberRow(baseRow(role: 'viewer'));

      expect(member.id, 'member-1');
      expect(member.role, WorkspaceRole.viewer);
    });

    test(
        'role null (colonna aggiunta da una migrazione non ancora pushata) '
        'non fa fallire il parsing: ricade su editor', () {
      final member = parseWorkspaceMemberRow(baseRow(role: null));

      expect(member.role, WorkspaceRole.editor);
    });
  });

  group('parseWorkspaceInviteRow', () {
    Map<String, dynamic> baseRow({Object? role = 'viewer'}) => {
          'id': 'invite-1',
          'workspace_id': 'ws-1',
          'code': 'ABCD1234',
          'created_by': 'user-1',
          'created_at': '2026-07-22T10:00:00.000Z',
          'expires_at': '2026-07-29T10:00:00.000Z',
          'role': role,
          'used_at': null,
          'used_by': null,
        };

    test('converte una riga completa in un WorkspaceInvite', () {
      final invite = parseWorkspaceInviteRow(baseRow(role: 'viewer'));

      expect(invite.id, 'invite-1');
      expect(invite.role, WorkspaceRole.viewer);
    });

    test(
        'role null (colonna aggiunta da una migrazione non ancora pushata) '
        'non fa fallire il parsing: ricade su editor', () {
      final invite = parseWorkspaceInviteRow(baseRow(role: null));

      expect(invite.role, WorkspaceRole.editor);
    });
  });
}
