import 'package:flutter/material.dart';

class CreateCompanyPage extends StatefulWidget {
  const CreateCompanyPage({super.key, required this.onCreate});

  final Future<void> Function(String companyName) onCreate;

  @override
  State<CreateCompanyPage> createState() => _CreateCompanyPageState();
}

class _CreateCompanyPageState extends State<CreateCompanyPage> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear empresa')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'Nombre de la empresa',
                hintText: 'Ej. HERMENCA',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final name = _ctrl.text.trim();
                        if (name.isEmpty) return;

                        setState(() => _busy = true);
                        try {
                          await widget.onCreate(name);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: Text(_busy ? 'Guardando...' : 'Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
