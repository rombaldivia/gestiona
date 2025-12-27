import 'package:flutter/material.dart';

class EditCompanyNamePage extends StatefulWidget {
  const EditCompanyNamePage({
    super.key,
    required this.initialName,
  });

  final String initialName;

  @override
  State<EditCompanyNamePage> createState() => _EditCompanyNamePageState();
}

class _EditCompanyNamePageState extends State<EditCompanyNamePage> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    // devolvemos el nombre nuevo; quien llama decide cómo persistir/sync
    if (!mounted) return;
    Navigator.of(context).pop(name);
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
              decoration: const InputDecoration(
                labelText: 'Nombre de la empresa',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
