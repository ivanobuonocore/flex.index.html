import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom Navigation a 4 sezioni, sempre accessibile. La Chat è la prima
/// (funzione principale, richiesta esplicita dell'utente — sostituisce
/// "Oggi": aprendo l'app si arriva subito su una conversazione, non su un
/// cruscotto). Ogni tab preserva il proprio stack di navigazione grazie a
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
              icon: Icon(Icons.person_outline), label: 'Profilo'),
        ],
      ),
    );
  }
}
