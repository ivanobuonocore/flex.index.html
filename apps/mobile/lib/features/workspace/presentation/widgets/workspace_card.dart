import 'package:flutter/material.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

/// Card Workspace (docs/product/05-design-system.md, "Card Workspace"):
/// nome, icona, ultima attività, stato — a colpo d'occhio l'utente capisce
/// dove riprendere il lavoro. Documenti/attività/AI dedicata arrivano in
/// Fase 2 insieme alle rispettive feature.
class WorkspaceCard extends StatelessWidget {
  const WorkspaceCard({super.key, required this.workspace, this.onTap});

  final Workspace workspace;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
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
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: AppRadii.buttonRadius,
                ),
                child: Icon(
                  _iconFor(workspace.icon),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workspace.name, style: theme.textTheme.headlineSmall),
                    if (workspace.description != null &&
                        workspace.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        workspace.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (workspace.status == WorkspaceStatus.archived)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text('Archiviato', style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),
      ),
    );
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
