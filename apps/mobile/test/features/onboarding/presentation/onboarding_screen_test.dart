import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/onboarding/presentation/onboarding_screen.dart';

import '../../../support/fake_auth_repository.dart';

/// Onboarding leggero al primo accesso (richiesta esplicita dell'utente):
/// 3 schermate scorrevoli, un pulsante "Salta" sempre disponibile, "Inizia"
/// solo sull'ultima — entrambi completano l'onboarding tramite il repository.
void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeAuthRepository fakeRepository,
  ) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepository)],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
  }

  testWidgets('mostra la prima schermata con il pulsante "Avanti"',
      (tester) async {
    final fakeRepository = FakeAuthRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);

    expect(find.text('Tutto parte dalla Chat'), findsOneWidget);
    expect(find.text('Avanti'), findsOneWidget);
    expect(find.text('Inizia'), findsNothing);
  });

  testWidgets('"Salta" completa l\'onboarding subito, da qualunque pagina',
      (tester) async {
    final fakeRepository = FakeAuthRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    await tester.tap(find.text('Salta'));
    await tester.pumpAndSettle();

    expect(fakeRepository.completeOnboardingCalled, isTrue);
  });

  testWidgets(
      '"Avanti" scorre le pagine, l\'ultima mostra "Inizia" che completa',
      (tester) async {
    final fakeRepository = FakeAuthRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);

    await tester.tap(find.text('Avanti'));
    await tester.pumpAndSettle();
    expect(find.text('I tuoi Spazi, sempre organizzati'), findsOneWidget);

    await tester.tap(find.text('Avanti'));
    await tester.pumpAndSettle();
    expect(find.text('L\'AI ricorda, tu decidi'), findsOneWidget);
    expect(find.text('Inizia'), findsOneWidget);
    expect(find.text('Avanti'), findsNothing);

    await tester.tap(find.text('Inizia'));
    await tester.pumpAndSettle();

    expect(fakeRepository.completeOnboardingCalled, isTrue);
  });
}
