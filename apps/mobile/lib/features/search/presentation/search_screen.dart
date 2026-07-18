import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';

/// Ricerca Universale (docs/product/06-information-architecture.md,
/// "Ricerca"). Richiede l'indicizzazione dei contenuti di Workspace
/// (Documenti, Chat, Task, ...), non ancora presenti in Fase 1.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ricerca')),
      body: const EmptyState(
        icon: Icons.search,
        title: 'La ricerca arriva con i tuoi contenuti',
        message:
            'Non appena creerai chat, documenti e attività, potrai trovarli tutti da qui.',
      ),
    );
  }
}
