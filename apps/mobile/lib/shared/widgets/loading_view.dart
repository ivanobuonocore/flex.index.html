import 'package:flutter/material.dart';

/// Stato "Loading" (docs/product/05-design-system.md, "Stati dell'app").
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
