import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Piccolo indicatore non invasivo, mostrato una sola volta per dispositivo,
/// per far scoprire una funzione già presente ma poco scoperta (richiesta
/// esplicita dell'utente). Lo stato "già visto" è puramente locale (nessun
/// dato di dominio, nessuna sincronizzazione tra dispositivi ha senso qui):
/// persistito con `shared_preferences`, prima dipendenza di storage locale
/// in questo progetto — finora ogni stato "già visto" (es. onboarding)
/// viveva lato Supabase perché doveva restare coerente tra i dispositivi
/// dello stesso utente, cosa non necessaria per un semplice suggerimento
/// grafico.
class CoachMark extends StatefulWidget {
  const CoachMark({
    super.key,
    required this.id,
    required this.message,
    required this.child,
  });

  /// Chiave stabile per questo coach mark (es. `'appuntamenti_calendario'`).
  final String id;
  final String message;
  final Widget child;

  @override
  State<CoachMark> createState() => _CoachMarkState();
}

class _CoachMarkState extends State<CoachMark> {
  static const _keyPrefix = 'coach_mark_seen_';

  // `null` finché non sappiamo ancora se sia già stato visto: in questo
  // stato non mostriamo nulla, per evitare un lampo del banner che poi
  // sparisce subito dopo la lettura da SharedPreferences.
  bool? _visible;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySeen = prefs.getBool('$_keyPrefix${widget.id}') ?? false;
    if (!mounted) return;
    setState(() => _visible = !alreadySeen);
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix${widget.id}', true);
  }

  @override
  Widget build(BuildContext context) {
    if (_visible != true) return widget.child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.heroGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadii.standardRadius,
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.message,
                  style: AppTypography.caption.copyWith(color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                tooltip: 'Chiudi',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _dismiss,
              ),
            ],
          ),
        ),
        widget.child,
      ],
    );
  }
}
