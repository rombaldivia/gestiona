import 'package:flutter/material.dart';

class WorkOrdersPage extends StatelessWidget {
  const WorkOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Órdenes de trabajo')),
      body: const Center(
        child: Text(
          'Pantalla de OT (placeholder)\n\nReemplázala por tu pantalla real.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
