import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom Navigation a 5 sezioni, sempre accessibile. La Chat è la prima
/// (funzione principale, richiesta esplicita dell'utente — sostituisce
/// "Oggi": aprendo l'app si arriva subito su una conversazione, non su un
/// cruscotto). "Bilancio" è la quinta voce (richiesta esplicita dell'utente):
/// aggrega entrate/uscite di tutti i Workspace in un grafico a torta, a
/// differenza del Bilancio per Workspace già presente nelle "cartelle" di
/// una Chat. Ogni tab preserva il proprio stack di navigazione grazie a
/// `StatefulShellRoute.indexedStack`.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(
              icon: Icon(Icons.folder_outlined), label: 'Workspace'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Ricerca'),
          NavigationDestination(
              icon: Icon(Icons.pie_chart_outline), label: 'Bilancio'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profilo'),
        ],
      ),
    );
  }
}
