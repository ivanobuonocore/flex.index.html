import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';

/// Bottom Navigation a 5 sezioni (redesign estetico — richiesta esplicita
/// dell'utente: "inseriscila al centro al posto di 'ricerca'... mettila in
/// risalto magari all'interno di un cerchio"). Chat, la funzione principale
/// dell'app, occupa il centro in un cerchio con un gradiente ispirato al
/// "glow" di Siri quando si attiva — non una voce come le altre, ma il punto
/// da cui parte tutto. Le altre 4 voci hanno ciascuna un colore distintivo
/// quando selezionate, coerente con "icone colorate" in tutta l'interfaccia.
/// Ogni tab preserva il proprio stack di navigazione grazie a
/// `StatefulShellRoute.indexedStack`.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _BottomBar(
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

const _barHeight = 64.0;
const _chatButtonSize = 60.0;

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          height: _barHeight + MediaQuery.of(context).padding.bottom,
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: AppShadows.card(isDark: isDark),
          ),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.folder_outlined,
                selectedIcon: Icons.folder,
                label: 'Workspace',
                color: AppColors.categoryDocumenti,
                selected: currentIndex == 0,
                onTap: () => onSelect(0),
              ),
              _NavItem(
                icon: Icons.pie_chart_outline,
                selectedIcon: Icons.pie_chart,
                label: 'Bilancio',
                color: AppColors.categoryBilancio,
                selected: currentIndex == 1,
                onTap: () => onSelect(1),
              ),
              const SizedBox(width: _chatButtonSize),
              _NavItem(
                icon: Icons.search_outlined,
                selectedIcon: Icons.search,
                label: 'Ricerca',
                color: AppColors.categoryAppuntamenti,
                selected: currentIndex == 3,
                onTap: () => onSelect(3),
              ),
              _NavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Profilo',
                color:
                    isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
                selected: currentIndex == 4,
                onTap: () => onSelect(4),
              ),
            ],
          ),
        ),
        Positioned(
          top: -_chatButtonSize / 2,
          child: _SiriChatButton(
            selected: currentIndex == 2,
            onTap: () => onSelect(2),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unselectedColor = theme.brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final tint = selected ? color : unselectedColor;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: tint),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.caption.copyWith(color: tint, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Il pulsante Chat, sempre al centro: un cerchio con un gradiente ispirato
/// al "glow" di Siri quando si attiva (richiesta esplicita dell'utente),
/// sollevato sopra la barra così risalta anche visivamente, non solo per
/// colore — l'utente deve percepirlo come il punto di partenza dell'app, non
/// come una quinta voce uguale alle altre.
class _SiriChatButton extends StatelessWidget {
  const _SiriChatButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glowIntensity = selected ? 0.55 : 0.35;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _chatButtonSize,
        height: _chatButtonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: AppColors.siriGlow,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            for (final color in AppColors.siriGlow)
              BoxShadow(
                color: color
                    .withOpacity(glowIntensity / AppColors.siriGlow.length),
                blurRadius: selected ? 24 : 16,
                spreadRadius: selected ? 2 : 0,
              ),
          ],
        ),
        child: const Icon(Icons.chat_bubble_rounded,
            color: Colors.white, size: 28),
      ),
    );
  }
}
