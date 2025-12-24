import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/data/auth_service.dart';
import '../../home/ui/home_page.dart';

import '../../subscription/presentation/entitlements_scope.dart';
import '../data/company_repository.dart';
import '../domain/company_summary.dart';

class CompanyGate extends StatefulWidget {
  const CompanyGate({
    super.key,
    required this.auth,
    required this.user,
  });

  final AuthService auth;
  final User user;

  @override
  State<CompanyGate> createState() => _CompanyGateState();
}

class _CompanyGateState extends State<CompanyGate> {
  final _repo = CompanyRepository();
  String? _selectedCompanyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Free => 1 empresa local fija
    final ent = EntitlementsScope.of(context);
    if (!ent.multiCompany && _selectedCompanyId == null) {
      _selectedCompanyId = 'local-default';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ent = EntitlementsScope.of(context);

    // FREE => directo
    if (!ent.multiCompany) {
      return HomePage(
        auth: widget.auth,
        companyId: _selectedCompanyId ?? 'local-default',
      );
    }

    // PLUS/PRO => selector si no hay empresa seleccionada
    if (_selectedCompanyId == null) {
      return StreamBuilder<List<CompanySummary>>(
        stream: _repo.watchUserCompanies(widget.user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final companies = snap.data ?? const <CompanySummary>[];

          return Scaffold(
            appBar: AppBar(
              title: const Text('Elegí una empresa'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan: ${ent.tier.asString.toUpperCase()}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Estas son las empresas vinculadas a tu cuenta.'),
                  const SizedBox(height: 16),

                  if (companies.isEmpty) ...[
                    const Text(
                      'No tenés empresas todavía en la nube.\n'
                      'Más adelante agregamos “Crear empresa”.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        // Placeholder para no bloquearte ahora:
                        setState(() => _selectedCompanyId = 'default');
                      },
                      child: const Text('Usar empresa "default" por ahora'),
                    ),
                  ] else ...[
                    Expanded(
                      child: ListView.separated(
                        itemCount: companies.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, i) {
                          final c = companies[i];
                          return ListTile(
                            title: Text(c.name),
                            subtitle: Text('ID: ${c.id}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => setState(() => _selectedCompanyId = c.id),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    }

    // Ya hay empresa seleccionada
    return HomePage(auth: widget.auth, companyId: _selectedCompanyId!);
  }
}
