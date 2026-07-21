import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../application/workspace_category_meta.dart';
import '../../application/workspace_controller.dart';
import '../edit_workspace_sheet.dart';

/// Card Workspace (docs/product/05-design-system.md, "Card Workspace"):
/// nome, icona, ultima attività, stato — a colpo d'occhio l'utente capisce
/// dove riprendere il lavoro. Una sezione fissa ([WorkspaceCategoryMeta])
/// prende icona/colore dalla categoria, non dai campi liberi `icon`/`color`
/// dell'utente, ed è rinominabile ma non eliminabile (richiesta esplicita
/// dell'utente: "vorrei che potessi modificarlo o anche eliminarlo",
/// applicabile solo ai Workspace liberi — le sezioni fisse sono strutturali).
class WorkspaceCard extends ConsumerWidget {
  const WorkspaceCard(
      {super.key, required this.workspace, this.onTap, this.subtitle});

  final Workspace workspace;
  final VoidCallback? onTap;

  /// Sostituisce la descrizione statica con un'anteprima viva (es. saldo del
  /// mese per Bilancio). Se `null`, mostra [Workspace.description].
  final Widget? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoryMeta = WorkspaceCategoryMeta.of(workspace.category);
    final isSystem = categoryMeta != null;
    final tint = categoryMeta?.color ?? theme.colorScheme.primary;
    final iconData = categoryMeta?.icon ?? _iconFor(workspace.icon);

    // Sostituisce la Card piatta (elevation 0 nel tema globale) con un
    // Container decorato: sfondo sfumato tenue nel colore della categoria +
    // ombra colorata (redesign estetico 2.0 — richiesta esplicita
    // dell'utente: "i Workspace... migliorati graficamente con
    // profondità, colori"), stesso principio già applicato alle sezioni in
    // Chat e all'hero del Bilancio, non una modifica al tema globale delle
    // Card (che resterebbe piatto ovunque non serva questo rilievo).
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tint.withOpacity(0.10), theme.colorScheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.standardRadius,
        boxShadow: AppShadows.glow(
          color: tint,
          isDark: theme.brightness == Brightness.dark,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.standardRadius,
        child: InkWell(
          borderRadius: AppRadii.standardRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [tint, tint.withOpacity(0.65)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: AppRadii.buttonRadius,
                    boxShadow: [
                      BoxShadow(
                        color: tint.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(iconData, color: Colors.white),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workspace.name,
                        style: theme.textTheme.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      subtitle ??
                          (workspace.description != null &&
                                  workspace.description!.isNotEmpty
                              ? Text(
                                  workspace.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                )
                              : const SizedBox.shrink()),
                    ],
                  ),
                ),
                PopupMenuButton<_WorkspaceCardAction>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) => _onAction(context, ref, action),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _WorkspaceCardAction.rename,
                      child: Text('Rinomina'),
                    ),
                    if (!isSystem)
                      const PopupMenuItem(
                        value: _WorkspaceCardAction.delete,
                        child: Text('Elimina'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _WorkspaceCardAction action,
  ) async {
    switch (action) {
      case _WorkspaceCardAction.rename:
        await showEditWorkspaceSheet(context, workspace: workspace);
      case _WorkspaceCardAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminare questo Workspace?'),
            content: Text(
              '"${workspace.name}" e i suoi contenuti non saranno più visibili. '
              'L\'azione non è immediatamente reversibile dall\'app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref
              .read(workspaceFormControllerProvider.notifier)
              .delete(workspace.id);
        }
    }
  }

  IconData _iconFor(String icon) {
    switch (icon) {
      case 'briefcase':
        return Icons.work_outline;
      case 'school':
        return Icons.school_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'campaign':
        return Icons.campaign_outlined;
      case 'flight':
        return Icons.flight_outlined;
      default:
        return Icons.folder_outlined;
    }
  }
}

enum _WorkspaceCardAction { rename, delete }
