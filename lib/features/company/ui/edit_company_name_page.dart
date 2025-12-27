import 'package:flutter/material.dart';

class EditCompanyNamePage extends StatefulWidget {
  const EditCompanyNamePage({super.key, required this.initialName});

  final String initialName;

  @override
  State<EditCompanyNamePage> createState() => _EditCompanyNamePageState();
}

class _EditCompanyNamePageState extends State<EditCompanyNamePage> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialName,
  );
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar empresa')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        final v = _ctrl.text.trim();
                        if (v.isEmpty) return;
                        setState(() => _busy = true);
                        Navigator.of(context).pop(v);
                      },
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
