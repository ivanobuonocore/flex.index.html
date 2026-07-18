import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom Navigation a 5 sezioni, sempre accessibile
/// (docs/product/05-design-system.md, "Bottom Navigation"). Ogni tab
/// preserva il proprio stack di navigazione grazie a
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
              icon: Icon(Icons.today_outlined), label: 'Today'),
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
