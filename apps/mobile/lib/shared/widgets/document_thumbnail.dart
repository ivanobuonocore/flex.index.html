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
///
/// Un tocco sull'immagine caricata apre un visualizzatore a schermo intero con
/// zoom (richiesta esplicita dell'utente: "lightbox per le foto allegate") —
/// solo nel caso `data` (un'anteprima ancora in caricamento o non
/// disponibile non ha nulla di significativo da ingrandire). Nella lista
/// Documenti la miniatura è il `leading` di una `ListTile` con un proprio
/// `onTap` (apre/scarica il file): il tocco specifico sull'immagine intercetta
/// solo quella piccola area, il resto della riga continua ad aprire il file
/// come prima.
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
        data: (url) => GestureDetector(
          onTap: () => _openLightbox(context, url),
          child: Image.network(
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
      ),
    );
  }

  void _openLightbox(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _ImageLightbox(url: url),
      ),
    );
  }
}

/// Visualizzatore a schermo intero con pan/zoom per una foto allegata —
/// sfondo nero pieno (non il tema dell'app: qui l'immagine è protagonista,
/// non l'interfaccia intorno), aperto da [DocumentThumbnail] al tocco.
class _ImageLightbox extends StatelessWidget {
  const _ImageLightbox({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(url),
        ),
      ),
    );
  }
}
