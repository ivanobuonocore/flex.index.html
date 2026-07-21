import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/auth/application/auth_controller.dart';
import 'package:pip_mobile/features/auth/application/session_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_auth_repository.dart';

void main() {
  final testUser = User(
    id: 'u1',
    email: 'ada@pip.app',
    name: 'Ada',
    plan: UserPlan.free,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  late FakeAuthRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepository)],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
  });

  test('signIn con successo aggiorna la sessione e non ritorna un errore',
      () async {
    fakeRepository.signInResult = Result.ok(testUser);

    // Sottoscrive la sessione prima del sign-in, cosi' il fake ha un listener attivo.
    final subscription =
        container.listen(sessionControllerProvider, (_, __) {});
    addTearDown(subscription.close);
    fakeRepository.emit(null);
    await container.read(sessionControllerProvider.future);

    final failure = await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'ada@pip.app', password: 'password123');
    await Future<void>.delayed(Duration.zero);

    expect(failure, isNull);
    expect(container.read(sessionControllerProvider).value, testUser);
  });

  test('signIn con credenziali errate ritorna un AuthFailure', () async {
    fakeRepository.signInResult =
        const Result.err(AuthFailure('Email o password non validi.'));

    final failure = await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'ada@pip.app', password: 'wrong-password');

    expect(failure, isA<AuthFailure>());
    expect(failure!.message, 'Email o password non validi.');
  });

  test('signOut invoca il repository e svuota la sessione', () async {
    final subscription =
        container.listen(sessionControllerProvider, (_, __) {});
    addTearDown(subscription.close);
    fakeRepository.emit(testUser);
    await container.read(sessionControllerProvider.future);

    await container.read(authControllerProvider.notifier).signOut();
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepository.signOutCalled, isTrue);
    expect(container.read(sessionControllerProvider).value, isNull);
  });

  test('updateThemeMode delega al repository e non ritorna errore', () async {
    final failure = await container
        .read(authControllerProvider.notifier)
        .updateThemeMode(AppThemeMode.dark);

    expect(failure, isNull);
    expect(fakeRepository.lastThemeMode, AppThemeMode.dark);
  });

  test('updateThemeMode propaga il Failure del repository', () async {
    fakeRepository.updateThemeModeResult =
        const Result.err(UnexpectedFailure('Salvataggio fallito.'));

    final failure = await container
        .read(authControllerProvider.notifier)
        .updateThemeMode(AppThemeMode.light);

    expect(failure, isA<UnexpectedFailure>());
  });
}
