import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';

import '../../features/document/application/document_controller.dart';

/// Miniatura di un [Document] immagine — la UI conosce solo l'id
/// (`Message.attachmentIds` in Chat, o direttamente `Document.id` nella lista
/// Documenti), quindi legge l'URL firmato tramite [documentDownloadUrlProvider]
/// prima di poterla mostrare. Estratto da `_AttachmentImage` (originariamente
/// solo per gli allegati di Chat — richiesta esplicita dell'utente: "miniature
/// per i Documenti") per essere condiviso anche da `document_list_screen.dart`.
///
/// `width` resta `null` per default (dimensione libera in base al contenuto,
/// comportamento invariato per la bolla di Chat) — passarlo esplicitamente
/// forza un riquadro quadrato, usato per la miniatura nella `ListTile.leading`
/// della lista Documenti. I riquadri di caricamento/errore restano più
/// piccoli dell'immagine finale (stesso rapporto 0.8/0.4 già usato prima di
/// questa estrazione: 160/80 su un'altezza di 200), scalati su [height] così
/// restano proporzionati anche alla dimensione più piccola della lista.
class DocumentThumbnail extends ConsumerWidget {
  const DocumentThumbnail({
    super.key,
    required this.documentId,
    this.height = 200,
    this.width,
  });

  final String documentId;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(documentDownloadUrlProvider(documentId));
    final loadingSize = height * 0.8;
    final errorSize = height * 0.4;

    return ClipRRect(
      borderRadius: AppRadii.standardRadius,
      child: urlAsync.when(
        loading: () => SizedBox(
          height: loadingSize,
          width: loadingSize,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => SizedBox(
          height: errorSize,
          width: errorSize,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        ),
        data: (url) => Image.network(
          url,
          height: height,
          width: width,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => SizedBox(
            height: errorSize,
            width: errorSize,
            child: const Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    );
  }
}
