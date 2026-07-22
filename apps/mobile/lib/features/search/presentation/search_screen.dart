import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/search_controller.dart';

/// Ricerca Universale (docs/product/06-information-architecture.md,
/// "Ricerca"): una sola barra, risultati cross-tabella su Workspace, Note,
/// Attività, Documenti, Transazioni confermate e Promemoria (richiesta
/// esplicita dell'utente, questi ultimi due). Chat/Memoria/Agenti
/// arriveranno con le rispettive feature (Fase 3+) senza richiedere
/// modifiche a questa schermata.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => ref.read(searchControllerProvider.notifier).search(value),
    );
  }

  void _open(SearchResult result) {
    switch (result.type) {
      case SearchResultType.workspace:
        context.push('/workspace/${result.workspaceId}');
      case SearchResultType.note:
        context.push('/workspace/${result.workspaceId}/notes');
      case SearchResultType.task:
        context.push('/workspace/${result.workspaceId}/tasks');
      case SearchResultType.document:
        context.push('/workspace/${result.workspaceId}/documents');
      case SearchResultType.transaction:
        context.push('/workspace/${result.workspaceId}/transactions');
      case SearchResultType.reminder:
        context.push('/workspace/${result.workspaceId}/reminders');
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchControllerProvider);

    return Scaffold(
      appBar: GradientAppBar(
        title: TextField(
          controller: _queryController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText:
                'Cerca in Workspace, Note, Attività, Documenti, Transazioni, Promemoria',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: resultsAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile completare la ricerca.',
          onRetry: () => ref
              .read(searchControllerProvider.notifier)
              .search(_queryController.text),
        ),
        data: (results) {
          if (_queryController.text.trim().isEmpty) {
            return const EmptyState(
              icon: Icons.search,
              title: 'Cerca tra i tuoi contenuti',
              message: 'Workspace, note, attività, documenti, transazioni e '
                  'promemoria: tutto in un unico posto.',
            );
          }
          if (results.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Nessun risultato',
              message: 'Prova con termini diversi.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final result = results[index];
              return Card(
                child: ListTile(
                  leading: Icon(_iconFor(result.type)),
                  title: Text(result.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: (result.snippet == null || result.snippet!.isEmpty)
                      ? Text(_typeLabel(result.type))
                      : Text(result.snippet!,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _open(result),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(SearchResultType type) => switch (type) {
        SearchResultType.workspace => Icons.space_dashboard_outlined,
        SearchResultType.note => Icons.sticky_note_2_outlined,
        SearchResultType.task => Icons.check_circle_outline,
        SearchResultType.document => Icons.insert_drive_file_outlined,
        SearchResultType.transaction => Icons.receipt_long_outlined,
        SearchResultType.reminder => Icons.notifications_outlined,
      };

  // Etichetta "Spazio" (rinominato da "Workspace" — richiesta esplicita
  // dell'utente), coerente con la tab "Spazi" e il titolo di
  // WorkspaceListScreen.
  String _typeLabel(SearchResultType type) => switch (type) {
        SearchResultType.workspace => 'Spazio',
        SearchResultType.note => 'Nota',
        SearchResultType.task => 'Attività',
        SearchResultType.document => 'Documento',
        SearchResultType.transaction => 'Transazione',
        SearchResultType.reminder => 'Promemoria',
      };
}
