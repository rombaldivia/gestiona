import 'package:flutter/material.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      body: const Center(
        child: Text(
          'Pantalla de Inventario (placeholder)\n\nReemplázala por tu pantalla real.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
