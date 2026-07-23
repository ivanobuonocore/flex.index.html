import 'dart:async';

import 'package:flutter/material.dart';

/// Mostra uno SnackBar con l'azione "Annulla" e posticipa l'eliminazione
/// reale di [delay] (richiesta esplicita dell'utente: "snackbar Annulla su
/// eliminazioni") — invece di cancellare subito, dà all'utente una finestra
/// per ripensarci. Se l'azione non viene toccata entro [delay], esegue
/// [onConfirmed] (la vera chiamata al repository); se viene toccata, esegue
/// [onUndo] invece e [onConfirmed] non viene mai chiamato.
///
/// Il chiamante resta responsabile di nascondere l'elemento dalla lista
/// subito (prima ancora di chiamare questa funzione) e di farlo ricomparire
/// dentro [onUndo] — stesso ruolo già svolto da un insieme locale di id
/// "scartati" nelle schermate con swipe-to-delete di questo progetto.
void scheduleUndoableDelete(
  BuildContext context, {
  required String message,
  required VoidCallback onConfirmed,
  required VoidCallback onUndo,
  Duration delay = const Duration(seconds: 4),
}) {
  final timer = Timer(delay, onConfirmed);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: delay,
      action: SnackBarAction(
        label: 'Annulla',
        onPressed: () {
          timer.cancel();
          onUndo();
        },
      ),
    ),
  );
}
