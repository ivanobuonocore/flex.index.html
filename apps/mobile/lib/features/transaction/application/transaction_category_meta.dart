import 'package:flutter/material.dart';
import 'package:pip_domain/pip_domain.dart';

/// Etichetta e icona di una [TransactionCategory] (Fase 3, slice 7C —
/// "Bilancio con categorie"): unica fonte di verità per non duplicare questi
/// dettagli tra il picker di creazione/modifica e le liste del Bilancio.
class TransactionCategoryMeta {
  const TransactionCategoryMeta({required this.label, required this.icon});

  final String label;
  final IconData icon;

  static const _byCategory = <TransactionCategory, TransactionCategoryMeta>{
    TransactionCategory.alimentari: TransactionCategoryMeta(
        label: 'Alimentari', icon: Icons.local_grocery_store_outlined),
    TransactionCategory.trasporti: TransactionCategoryMeta(
        label: 'Trasporti', icon: Icons.directions_bus_outlined),
    TransactionCategory.casa:
        TransactionCategoryMeta(label: 'Casa', icon: Icons.home_outlined),
    TransactionCategory.bollette: TransactionCategoryMeta(
        label: 'Bollette', icon: Icons.receipt_long_outlined),
    TransactionCategory.salute: TransactionCategoryMeta(
        label: 'Salute', icon: Icons.local_hospital_outlined),
    TransactionCategory.svago: TransactionCategoryMeta(
        label: 'Svago', icon: Icons.local_activity_outlined),
    TransactionCategory.shopping: TransactionCategoryMeta(
        label: 'Shopping', icon: Icons.shopping_bag_outlined),
    TransactionCategory.istruzione: TransactionCategoryMeta(
        label: 'Istruzione', icon: Icons.school_outlined),
    TransactionCategory.stipendio: TransactionCategoryMeta(
        label: 'Stipendio', icon: Icons.payments_outlined),
    TransactionCategory.altro:
        TransactionCategoryMeta(label: 'Altro', icon: Icons.category_outlined),
  };

  static TransactionCategoryMeta of(TransactionCategory category) =>
      _byCategory[category]!;
}
