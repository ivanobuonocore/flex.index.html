import 'package:flutter/material.dart';

/// Icona colorata e rotonda: una firma visiva coerente per le sezioni
/// principali dell'app, ispirata ai badge rapidi delle app di messaggistica.
class ColorfulIconBadge extends StatelessWidget {
  const ColorfulIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.68)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.28),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: iconSize ?? size * 0.48,
      ),
    );
  }
}
