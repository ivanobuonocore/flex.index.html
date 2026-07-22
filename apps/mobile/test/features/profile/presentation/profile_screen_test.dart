import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/profile/presentation/profile_screen.dart';

import '../../../support/fake_auth_repository.dart';

/// Sync con Google Calendar (integrazione richiesta esplicitamente): la
/// card "Google Calendar" in Profilo è nascosta finché l'app non è
/// compilata con `--dart-define=GOOGLE_CALENDAR_ENABLED=true`
/// (`AppEnv.googleCalendarEnabled`, una costante di compilazione, non
/// sovrascrivibile a runtime da un test — stesso limite già esistente per
/// `_NotificationsCard`/VAPID, mai forzato a `true` in nessun test di questo
/// progetto). Questo test verifica solo che, con il valore di default
/// (assente), Profilo resti utilizzabile e la card non compaia — il
/// comportamento con il collegamento attivo/non attivo non è quindi
/// esercitabile in questa sandbox, dichiarato esplicitamente in
/// docs/database/README.md.
void main() {
  testWidgets(
      'senza GOOGLE_CALENDAR_ENABLED la card Google Calendar non compare',
      (tester) async {
    final fakeAuth = FakeAuthRepository();
    addTearDown(fakeAuth.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    fakeAuth.emit(User(
      id: 'u1',
      email: 'ada@pip.app',
      name: 'Ada',
      plan: UserPlan.free,
      createdAt: DateTime.utc(2026, 1, 1),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Google Calendar'), findsNothing);
    expect(find.text('Connetti Google Calendar'), findsNothing);
    // Il resto della schermata resta comunque utilizzabile.
    expect(find.text('Ada'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Esci'), 200);
    expect(find.text('Esci'), findsOneWidget);
  });
}
