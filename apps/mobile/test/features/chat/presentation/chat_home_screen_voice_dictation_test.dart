import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/main.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_chat_repository.dart';
import '../../../support/fake_document_repository.dart';
import '../../../support/fake_message_repository.dart';
import '../../../support/fake_speech_to_text_platform.dart';
import '../../../support/fake_task_repository.dart';
import '../../../support/fake_transaction_repository.dart';
import '../../../support/fake_workspace_repository.dart';

/// Dettatura vocale in Chat (integrazione richiesta esplicitamente). Solo il
/// lato "canale disponibile/non disponibile e trascrizione ricevuta" è
/// esercitabile qui, tramite [FakeSpeechToTextPlatform] (lo stesso seam di
/// test del plugin federato `speech_to_text`, usato anche dalla sua
/// implementazione web reale) — nessun test in questa sandbox può verificare
/// il supporto reale del Web Speech API in un browser vero, dichiarato
/// esplicitamente in docs/database/README.md.
///
/// **Ordine dei test non arbitrario**: `SpeechToText()` è una factory che
/// ritorna sempre lo stesso singleton di processo (`SpeechToText._instance`,
/// vedi il package), il cui flag interno `_initWorked` — una volta diventato
/// `true` dopo un `initialize()` riuscito — resta tale per il resto del
/// processo, facendo sì che ogni `initialize()` successivo ritorni
/// immediatamente `true` senza più interpellare
/// `SpeechToTextPlatform.instance` (osservato empiricamente: con l'ordine
/// invertito il secondo test riceve `available: true` anche se il suo fake è
/// configurato per fallire). Per questo l'unico test che porta
/// `initialize()` a un successo permanente è l'ultimo di questo file.
void main() {
  final user = User(
    id: 'u1',
    email: 'ada@pip.app',
    name: 'Ada',
    plan: UserPlan.free,
    createdAt: DateTime.utc(2026, 1, 1),
    onboardingCompleted: true,
  );
  final chat = Chat(
    id: 'c1',
    ownerId: 'u1',
    title: 'Assistente',
    aiModel: 'claude-sonnet-5',
    status: ChatStatus.active,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  Future<FakeSpeechToTextPlatform> pumpChat(
    WidgetTester tester, {
    required bool initializeResult,
  }) async {
    final fakeSpeech = FakeSpeechToTextPlatform()
      ..initializeResult = initializeResult;
    SpeechToTextPlatform.instance = fakeSpeech;

    final fakeAuth = FakeAuthRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeChat = FakeChatRepository();
    final fakeMessage = FakeMessageRepository();
    final fakeTask = FakeTaskRepository();
    final fakeDocument = FakeDocumentRepository();
    final fakeTransaction = FakeTransactionRepository();
    addTearDown(fakeAuth.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeChat.dispose);
    addTearDown(fakeMessage.dispose);
    addTearDown(fakeTask.dispose);
    addTearDown(fakeDocument.dispose);
    addTearDown(fakeTransaction.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          chatRepositoryProvider.overrideWithValue(fakeChat),
          messageRepositoryProvider.overrideWithValue(fakeMessage),
          taskRepositoryProvider.overrideWithValue(fakeTask),
          documentRepositoryProvider.overrideWithValue(fakeDocument),
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
        ],
        child: const PipApp(),
      ),
    );

    fakeAuth.emit(user);
    await tester.pump();
    fakeWorkspace.emit(const []);
    fakeChat.emit([chat]);
    await tester.pump();
    fakeMessage.emit(const []);
    await tester.pumpAndSettle();

    return fakeSpeech;
  }

  testWidgets(
      'con la dettatura non disponibile non mostra il pulsante microfono',
      (tester) async {
    await pumpChat(tester, initializeResult: false);

    expect(find.byIcon(Icons.mic_none_outlined), findsNothing);
    expect(find.byIcon(Icons.mic), findsNothing);
  });

  testWidgets(
      'con la dettatura disponibile: mostra il microfono, avvia/ferma '
      'l\'ascolto e la trascrizione sostituisce il testo del campo',
      (tester) async {
    final fakeSpeech = await pumpChat(tester, initializeResult: true);

    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mic_none_outlined));
    await tester.pump();

    expect(fakeSpeech.listenCallCount, 1);
    expect(find.byIcon(Icons.mic), findsOneWidget);

    fakeSpeech.emitResult('barbiere 23 euro');
    await tester.pump();

    expect(find.widgetWithText(TextField, 'barbiere 23 euro'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();

    expect(fakeSpeech.stopCallCount, 1);
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);

    // `stop()` di SpeechToText programma un timer interno (finalTimeout, 2s
    // di default) per il "fallback" al risultato finale: senza farlo scadere
    // qui, il test framework segnala un timer ancora pendente a fine test.
    await tester.pump(const Duration(seconds: 3));
  });
}
