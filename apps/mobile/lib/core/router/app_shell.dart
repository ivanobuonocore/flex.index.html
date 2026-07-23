import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';

import '../../features/transaction/application/transaction_controller.dart';

/// Bottom Navigation a 5 sezioni (redesign estetico — richiesta esplicita
/// dell'utente: "inseriscila al centro al posto di 'ricerca'... mettila in
/// risalto magari all'interno di un cerchio"). Chat, la funzione principale
/// dell'app, occupa il centro in un cerchio con un gradiente ispirato al
/// "glow" di Siri quando si attiva — non una voce come le altre, ma il punto
/// da cui parte tutto. Le altre 4 voci hanno ciascuna un colore distintivo
/// quando selezionate, coerente con "icone colorate" in tutta l'interfaccia.
/// Ogni tab preserva il proprio stack di navigazione grazie a
/// `StatefulShellRoute.indexedStack`.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Badge sul pulsante Chat (richiesta esplicita dell'utente: "badge sulla
    // tab... Chat"): conta le transazioni suggerite dall'AI ancora da
    // confermare/scartare (AI Constitution, Principio 1) — è lì, dentro la
    // Chat, che si confermano o scartano (task #93), quindi è la cosa più
    // sensata da segnalare su questo pulsante, non un concetto di "messaggio
    // non letto" che qui non esiste (la Chat è sempre la Home).
    final pendingTransactionsCount =
        ref.watch(transactionsProvider(null)).maybeWhen(
              data: (transactions) => pendingTransactions(transactions).length,
              orElse: () => 0,
            );

    return Scaffold(
      // Ogni sezione entra con una dissolvenza e un lieve scorrimento. Il
      // contenuto non cambia e le tab continuano a conservare il proprio
      // stato grazie allo StatefulShellRoute.
      body: TweenAnimationBuilder<double>(
        key: ValueKey(navigationShell.currentIndex),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        ),
        child: navigationShell,
      ),
      bottomNavigationBar: _BottomBar(
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        pendingTransactionsCount: pendingTransactionsCount,
      ),
    );
  }
}

const _barHeight = 64.0;
const _chatButtonSize = 60.0;

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.onSelect,
    required this.pendingTransactionsCount,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final int pendingTransactionsCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final barBoxHeight = _barHeight + bottomPadding;

    // L'intero riquadro (non solo la barra) deve includere il cerchio
    // sollevato: Scaffold instrada hover/tap solo ai punti dentro le
    // dimensioni effettive di ciò che passa a `bottomNavigationBar` — con
    // `Positioned(top: negativo)` + `Clip.none` (versione precedente) la
    // metà superiore del cerchio, quella visivamente più in vista, veniva
    // dipinta ma non riceveva mai eventi (bug segnalato dall'utente: "ancora
    // non va" dopo il primo fix del cursore/hover).
    return SizedBox(
      height: barBoxHeight + _chatButtonSize / 2,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: barBoxHeight,
              padding: EdgeInsets.only(bottom: bottomPadding),
              // Alone tenue centrato sul pulsante Chat, non un colore piatto
              // (redesign estetico 2.0 — richiesta esplicita dell'utente: "la
              // chat... le sezioni in basso facciano da contorno"): la barra
              // sembra "emanare" dal pulsante centrale invece di un
              // contenitore neutro con 5 voci equivalenti — rinforza la
              // gerarchia visiva senza cambiare il pulsante stesso né la
              // navigazione.
              decoration: BoxDecoration(
                // AppColors.heroGradient (blu → viola), non siriGlow: un'unica
                // palette coerente in tutta l'app (richiesta esplicita
                // dell'utente), il pulsante Chat resta l'unico punto con il
                // gradiente animato a più colori.
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.3,
                  colors: [
                    AppColors.heroGradient.first
                        .withOpacity(isDark ? 0.14 : 0.08),
                    theme.colorScheme.surface,
                  ],
                ),
                boxShadow: AppShadows.card(isDark: isDark),
              ),
              child: Row(
                children: [
                  _NavItem(
                    // Rinominato da "Workspace" a "Spazi" (richiesta esplicita
                    // dell'utente: "trova un altro termine... e metti
                    // un'immagine diversa"), solo l'etichetta e l'icona
                    // visibili — nessuna classe/route interna rinominata
                    // (WorkspaceCard, /workspace/:id, ecc. restano invariate:
                    // una rinomina estesa non richiesta, solo cosmetica).
                    icon: Icons.space_dashboard_outlined,
                    selectedIcon: Icons.space_dashboard,
                    label: 'Spazi',
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
                    // Al posto di "Ricerca" (richiesta esplicita
                    // dell'utente): la Ricerca Universale resta raggiungibile
                    // da un'icona in Chat Home, non più da qui.
                    icon: Icons.event_outlined,
                    selectedIcon: Icons.event,
                    label: 'Appuntamenti',
                    color: AppColors.categoryAppuntamenti,
                    selected: currentIndex == 3,
                    onTap: () => onSelect(3),
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'Profilo',
                    color: isDark
                        ? AppColors.secondaryDark
                        : AppColors.secondaryLight,
                    selected: currentIndex == 4,
                    onTap: () => onSelect(4),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: _SiriChatButton(
                selected: currentIndex == 2,
                onTap: () => onSelect(2),
                pendingCount: pendingTransactionsCount,
              ),
            ),
          ),
        ],
      ),
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
    // Più piccole da ferme, a piena dimensione solo se selezionate (redesign
    // estetico 2.0 — richiesta esplicita dell'utente: "le sezioni in basso
    // facciano da contorno" rispetto al pulsante Chat centrale): un peso
    // visivo minore per le 4 voci laterali, non solo un colore più tenue.
    final iconSize = selected ? 24.0 : 20.0;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1 : 0.92,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                color: tint,
                size: iconSize,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.caption
                    .copyWith(color: tint, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il pulsante Chat, sempre al centro: un cerchio con un gradiente ispirato
/// al "glow" di Siri quando si attiva (richiesta esplicita dell'utente),
/// sollevato sopra la barra così risalta anche visivamente, non solo per
/// colore — l'utente deve percepirlo come il punto di partenza dell'app, non
/// come una quinta voce uguale alle altre. `Material`+`InkWell` (non un
/// semplice `GestureDetector`, che su web non cambia il cursore né dà alcun
/// segnale al passaggio del mouse — bug segnalato dall'utente: "se vado con
/// il cursore sopra l'icona chat non mi esce nulla") danno il cursore a
/// manina e il ripple standard; al passaggio del mouse ("colori dinamici in
/// movimento", richiesta esplicita) il gradiente ruota di continuo finché il
/// cursore resta sopra.
class _SiriChatButton extends StatefulWidget {
  const _SiriChatButton({
    required this.selected,
    required this.onTap,
    required this.pendingCount,
  });

  final bool selected;
  final VoidCallback onTap;

  /// Transazioni suggerite dall'AI ancora da confermare/scartare — badge
  /// (richiesta esplicita dell'utente: "badge sulla tab... Chat").
  final int pendingCount;

  @override
  State<_SiriChatButton> createState() => _SiriChatButtonState();
}

class _SiriChatButtonState extends State<_SiriChatButton>
    with SingleTickerProviderStateMixin {
  late final _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  bool _hovering = false;

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  void _setHovering(bool hovering) {
    if (_hovering == hovering) return;
    setState(() => _hovering = hovering);
    if (hovering) {
      _rotation.repeat();
    } else {
      _rotation.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final glowIntensity = widget.selected ? 0.55 : 0.35;

    return Tooltip(
      message: 'Chat',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onTap,
          onHover: _setHovering,
          child: AnimatedBuilder(
            animation: _rotation,
            builder: (context, child) {
              return Badge(
                isLabelVisible: widget.pendingCount > 0,
                label: Text('${widget.pendingCount}'),
                backgroundColor: AppColors.error,
                child: Container(
                  width: _chatButtonSize,
                  height: _chatButtonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [...AppColors.siriGlow, AppColors.siriGlow.first],
                      transform:
                          GradientRotation(_rotation.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      for (final color in AppColors.siriGlow)
                        BoxShadow(
                          color: color.withOpacity(
                            (_hovering ? glowIntensity * 1.4 : glowIntensity) /
                                AppColors.siriGlow.length,
                          ),
                          blurRadius:
                              _hovering ? 28 : (widget.selected ? 24 : 16),
                          spreadRadius:
                              _hovering ? 3 : (widget.selected ? 2 : 0),
                        ),
                    ],
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: Colors.white, size: 28),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
