import 'package:flutter/material.dart';

class TaxesRedirectPage extends StatelessWidget {
  const TaxesRedirectPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Aquí luego podemos abrir un link (Impuestos Bolivia / SIN / etc.)
    // con url_launcher cuando tú me digas el destino exacto.
    return Scaffold(
      appBar: AppBar(title: const Text('Facturación / Impuestos')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Redirección a impuestos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Aquí vamos a redirigir a la página de impuestos.\n'
                  'Dime cuál URL exacta quieres abrir (SIN/Impuestos) y lo conecto.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL pendiente de definir')),
                      );
                    },
                    child: const Text('Abrir impuestos'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
