import 'package:flutter/material.dart';
import '../data/company_service.dart';

class CreateCompanyPage extends StatefulWidget {
  const CreateCompanyPage({super.key, required this.companyService});
  final CompanyService companyService;

  @override
  State<CreateCompanyPage> createState() => _CreateCompanyPageState();
}

class _CreateCompanyPageState extends State<CreateCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear empresa')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 44,
                              width: 44,
                              decoration: BoxDecoration(
                                color: cs.primary.withAlpha(
                                  (0.12 * 255).round(),
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.apartment, color: cs.primary),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tu primera empresa',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Crea una empresa para empezar a usar Gestiona.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la empresa',
                            hintText: 'Ej: HERMENCA Ltda.',
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return 'Escribe un nombre';
                            if (s.length < 3) return 'Muy corto';
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _loading
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate())
                                    return;

                                  setState(() => _loading = true);
                                  try {
                                    await widget.companyService
                                        .createCompanyAndMembership(
                                          companyName: _name.text,
                                        );

                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Empresa creada ✅'),
                                      ),
                                    );
                                    // No navegamos: CompanyGate detectará membership y entrará solo.
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  } finally {
                                    if (mounted)
                                      setState(() => _loading = false);
                                  }
                                },
                          child: _loading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(),
                                )
                              : const Text('Crear empresa'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
