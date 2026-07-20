import 'package:flutter/material.dart';
import 'package:pip_domain/pip_domain.dart';

/// Etichetta, icona e colore di una [TransactionCategory] (Fase 3, slice 7C
/// — "Bilancio con categorie", colori aggiunti nel redesign estetico —
/// richiesta esplicita dell'utente: "icone colorate"): unica fonte di
/// verità per non duplicare questi dettagli tra il picker di
/// creazione/modifica e le liste del Bilancio.
class TransactionCategoryMeta {
  const TransactionCategoryMeta({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  static const _byCategory = <TransactionCategory, TransactionCategoryMeta>{
    TransactionCategory.alimentari: TransactionCategoryMeta(
      label: 'Alimentari',
      icon: Icons.local_grocery_store_outlined,
      color: Color(0xFF16A34A),
    ),
    TransactionCategory.trasporti: TransactionCategoryMeta(
      label: 'Trasporti',
      icon: Icons.directions_bus_outlined,
      color: Color(0xFF2563EB),
    ),
    TransactionCategory.casa: TransactionCategoryMeta(
      label: 'Casa',
      icon: Icons.home_outlined,
      color: Color(0xFF0D9488),
    ),
    TransactionCategory.bollette: TransactionCategoryMeta(
      label: 'Bollette',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFFF59E0B),
    ),
    TransactionCategory.salute: TransactionCategoryMeta(
      label: 'Salute',
      icon: Icons.local_hospital_outlined,
      color: Color(0xFFEF4444),
    ),
    TransactionCategory.svago: TransactionCategoryMeta(
      label: 'Svago',
      icon: Icons.local_activity_outlined,
      color: Color(0xFFB24CFF),
    ),
    TransactionCategory.shopping: TransactionCategoryMeta(
      label: 'Shopping',
      icon: Icons.shopping_bag_outlined,
      color: Color(0xFFFF5DA2),
    ),
    TransactionCategory.istruzione: TransactionCategoryMeta(
      label: 'Istruzione',
      icon: Icons.school_outlined,
      color: Color(0xFF4F7BFF),
    ),
    TransactionCategory.stipendio: TransactionCategoryMeta(
      label: 'Stipendio',
      icon: Icons.payments_outlined,
      color: Color(0xFF16A34A),
    ),
    TransactionCategory.altro: TransactionCategoryMeta(
      label: 'Altro',
      icon: Icons.category_outlined,
      color: Color(0xFF6B7280),
    ),
  };

  static TransactionCategoryMeta of(TransactionCategory category) =>
      _byCategory[category]!;
}
