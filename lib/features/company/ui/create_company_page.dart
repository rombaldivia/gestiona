import 'package:flutter/material.dart';

import '../../subscription/presentation/entitlements_scope.dart';
import '../data/company_offline_first_service.dart';

class CreateCompanyPage extends StatefulWidget {
  const CreateCompanyPage({super.key, required this.service});
  final CompanyOfflineFirstService service;

  @override
  State<CreateCompanyPage> createState() => _CreateCompanyPageState();
}

class _CreateCompanyPageState extends State<CreateCompanyPage> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);

    try {
      final ent = EntitlementsScope.of(context);
      await widget.service.createCompanyOfflineFirst(companyName: name, ent: ent);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ent = EntitlementsScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva empresa')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'Nombre de la empresa',
                hintText: 'Ej: HERMENCA',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                ent.cloudSync
                    ? 'Se guardará local y se sincronizará en la nube.'
                    : 'Se guardará local (para nube necesitas Plus/Pro).',
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _create,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Guardando...' : 'Crear'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
