import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  group('User', () {
    final createdAt = DateTime.utc(2026, 1, 1);

    test('copyWith aggiorna solo i campi indicati', () {
      final user = User(
        id: 'u1',
        email: 'a@pip.app',
        name: 'Ada',
        plan: UserPlan.free,
        createdAt: createdAt,
      );

      final upgraded = user.copyWith(plan: UserPlan.pro);

      expect(upgraded.plan, UserPlan.pro);
      expect(upgraded.id, user.id);
      expect(upgraded.email, user.email);
      expect(upgraded.name, user.name);
    });

    test('themeMode di default è system', () {
      final user = User(
        id: 'u1',
        email: 'a@pip.app',
        name: 'Ada',
        plan: UserPlan.free,
        createdAt: createdAt,
      );

      expect(user.themeMode, AppThemeMode.system);
    });

    test('copyWith aggiorna themeMode', () {
      final user = User(
        id: 'u1',
        email: 'a@pip.app',
        name: 'Ada',
        plan: UserPlan.free,
        createdAt: createdAt,
      );

      final updated = user.copyWith(themeMode: AppThemeMode.dark);

      expect(updated.themeMode, AppThemeMode.dark);
    });

    test('due utenti con stessi campi sono uguali per valore', () {
      final a = User(
          id: 'u1',
          email: 'a@pip.app',
          name: 'Ada',
          plan: UserPlan.free,
          createdAt: createdAt);
      final b = User(
          id: 'u1',
          email: 'a@pip.app',
          name: 'Ada',
          plan: UserPlan.free,
          createdAt: createdAt);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
