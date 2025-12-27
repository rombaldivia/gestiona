import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../../subscription/presentation/entitlements_scope.dart';
import '../data/company_offline_first_service.dart';
import '../presentation/company_scope.dart';
import '../ui/create_company_page.dart';
import '../../home/ui/home_page.dart';

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
  late final CompanyOfflineFirstService _service;

  String? _companyId;
  String? _companyName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = CompanyOfflineFirstService();
    _loadActiveFromLocal();
  }

  Future<void> _loadActiveFromLocal() async {
    final active = await _service.getActiveLocalCompany();
    if (!mounted) return;

    setState(() {
      _companyId = active?.$1;
      _companyName = active?.$2;
      _loading = false;
    });
  }

  Future<void> _ensureCompany() async {
    // Abre pantalla crear empresa. Al volver, recarga local.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateCompanyPage(service: _service),
      ),
    );
    await _loadActiveFromLocal();
  }

  @override
  Widget build(BuildContext context) {
    final ent = EntitlementsScope.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_companyId == null || _companyName == null) {
      // No hay empresa guardada -> crear
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.apartment, size: 56),
                  const SizedBox(height: 10),
                  const Text(
                    'Bienvenido 👋',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text('Crea tu primera empresa para empezar.'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _ensureCompany,
                      icon: const Icon(Icons.add),
                      label: const Text('Crear empresa'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return CompanyScope(
      companyId: _companyId!,
      companyName: _companyName!,
      child: HomePage(
        auth: widget.auth,
        user: widget.user,
        onSyncPressed: () async {
          // Sync del active local -> nube, solo Plus/Pro
          // (el botón en UI ya está disabled si no cloudSync)
          await _service.syncActiveCompany(ent: ent);
        },
      ),
    );
  }
}
