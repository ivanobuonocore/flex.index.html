import 'package:flutter/material.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

/// Etichetta, icona, colore e descrizione di una sezione fissa
/// ([SystemWorkspaceCategory]) — unica fonte di verità per non duplicare
/// questi dettagli tra [WorkspaceCard], la striscia "Sezioni" e il bootstrap
/// che crea le sezioni al primo accesso (AGENTS.md §8, Design System).
class WorkspaceCategoryMeta {
  const WorkspaceCategoryMeta({
    required this.label,
    required this.description,
    required this.icon,
    required this.emoji,
    required this.color,
  });

  final String label;
  final String description;
  final IconData icon;
  /// Emoji nativa, volutamente colorata: rende le sezioni riconoscibili e
  /// conserva il tono più personale dell'app accanto alle icone di sistema.
  final String emoji;
  final Color color;

  static const _byCategory = <String, WorkspaceCategoryMeta>{
    SystemWorkspaceCategory.bilancio: WorkspaceCategoryMeta(
      label: 'Bilancio',
      description: 'Entrate e uscite scritte in Chat',
      icon: Icons.pie_chart_outline,
      emoji: '💰',
      color: AppColors.categoryBilancio,
    ),
    SystemWorkspaceCategory.appuntamenti: WorkspaceCategoryMeta(
      label: 'Appuntamenti',
      description: 'Eventi e promemoria dalla Chat',
      icon: Icons.event_outlined,
      emoji: '📅',
      color: AppColors.categoryAppuntamenti,
    ),
    SystemWorkspaceCategory.attivita: WorkspaceCategoryMeta(
      label: 'Attività',
      description: 'Liste e cose da fare dalla Chat',
      icon: Icons.checklist_outlined,
      emoji: '✅',
      color: AppColors.categoryAttivita,
    ),
    SystemWorkspaceCategory.documenti: WorkspaceCategoryMeta(
      label: 'Documenti',
      description: 'Foto e file condivisi in Chat',
      icon: Icons.description_outlined,
      emoji: '📄',
      color: AppColors.categoryDocumenti,
    ),
  };

  /// `null` se [category] non è una sezione fissa (Workspace libero
  /// dell'utente).
  static WorkspaceCategoryMeta? of(String? category) =>
      category == null ? null : _byCategory[category];

  static bool isSystem(String? category) =>
      category != null && _byCategory.containsKey(category);
}
