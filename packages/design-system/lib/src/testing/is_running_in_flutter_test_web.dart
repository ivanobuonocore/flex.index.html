/// Sul web `flutter test` gira nel browser, non in una VM con variabili
/// d'ambiente: qui non serve comunque evitare `google_fonts` (i test di
/// questo progetto girano sulla piattaforma VM, non Chrome), quindi `false`.
bool get isRunningInFlutterTest => false;
