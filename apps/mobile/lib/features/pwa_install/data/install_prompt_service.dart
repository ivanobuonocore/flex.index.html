/// Confine verso l'evento browser `beforeinstallprompt` (installazione PWA)
/// — implementazione scelta a compile time in base alla piattaforma (vedi
/// `install_prompt_service_provider.dart`, stesso pattern già usato per le
/// notifiche push in `features/notifications/`). Nessun metodo di questa
/// interfaccia importa `dart:js_interop` o `package:web`: solo
/// l'implementazione web lo fa.
abstract interface class InstallPromptService {
  /// Emette `true` quando il browser rende disponibile il prompt di
  /// installazione, `false` dopo che l'utente ha installato l'app. Se non
  /// arriva mai un evento (piattaforma non Chromium/Edge, app già
  /// installata, iOS Safari che non lo supporta affatto) lo stream non
  /// emette nulla: il chiamante tratta "nessun evento" come "non
  /// disponibile", non come un errore.
  Stream<bool> watchAvailability();

  /// Mostra il prompt nativo del browser. No-op se non è mai arrivato alcun
  /// evento da mostrare — il pulsante che lo chiama dovrebbe già essere
  /// nascosto in quel caso.
  Future<void> promptInstall();
}
