import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state.dart';

/// Area Chat (docs/product/06-information-architecture.md, "Chat").
/// L'AI Engine che orchestra le conversazioni arriva in Fase 3
/// (docs/product/26-execution-blueprint.md); qui la navigazione è già
/// raggiungibile, in attesa della feature completa.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: const EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'Le conversazioni arrivano presto',
        message:
            'La Chat sarà collegata all\'AI Engine nella Fase 3 della roadmap.',
      ),
    );
  }
}
