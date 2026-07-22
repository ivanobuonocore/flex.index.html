import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/data_export_controller.dart';

/// Foglio "Esporta i miei dati" (richiesta esplicita dell'utente). Niente
/// PDF/file scaricabile: `pdf`/`share_plus` non sono pacchetti disponibili in
/// questo ambiente di build (stesso limite dichiarato per il riepilogo
/// mensile del Bilancio) — copia negli appunti e invio via email coprono lo
/// stesso bisogno di portabilità dei dati senza dipendenze nuove.
Future<void> showDataExportSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _DataExportSheet(),
  );
}

class _DataExportSheet extends ConsumerStatefulWidget {
  const _DataExportSheet();

  @override
  ConsumerState<_DataExportSheet> createState() => _DataExportSheetState();
}

class _DataExportSheetState extends ConsumerState<_DataExportSheet> {
  @override
  void initState() {
    super.initState();
    // Avviato da qui, non dal chiamante di [showDataExportSheet]: tra quella
    // chiamata e l'apertura effettiva del bottom sheet passa l'animazione di
    // `showModalBottomSheet` (più frame), durante la quale nessuno ancora
    // osserva `dataExportControllerProvider` — un provider `autoDispose`
    // verrebbe ricreato da zero nel frattempo, perdendo il risultato.
    // `initState()` e la prima `build()` avvengono nello stesso ciclo
    // sincrono, quindi il provider resta vivo.
    Future.microtask(
        () => ref.read(dataExportControllerProvider.notifier).generate());
  }

  @override
  Widget build(BuildContext context) {
    final exportAsync = ref.watch(dataExportControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Esporta i miei dati', style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Un file JSON con Note, Attività, Documenti (elenco), '
              'Promemoria, Transazioni e Memoria di tutti i tuoi Workspace.',
            ),
            const SizedBox(height: AppSpacing.md),
            exportAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Text(
                'Non è stato possibile generare l\'export. Riprova.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              data: (json) {
                if (json == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${json.length} caratteri pronti.',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: json));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Export copiato negli appunti.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copia negli appunti'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => _sendExportByEmail(context, json),
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Invia via email'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _sendExportByEmail(BuildContext context, String json) async {
  final uri = Uri(
    scheme: 'mailto',
    query: 'subject=${Uri.encodeComponent('Export dati PIP')}'
        '&body=${Uri.encodeComponent(json)}',
  );
  final launched = await launchUrl(uri);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Non è stato possibile aprire un\'app email. Usa "Copia negli '
              'appunti" e incollalo in un\'email.')),
    );
  }
}
