import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../../home/ui/home_page.dart';
import '../../subscription/presentation/entitlements_scope.dart';
import '../data/company_offline_first_service.dart';
import '../ui/create_company_page.dart';
import '../ui/edit_company_name_page.dart';
import 'company_scope.dart';

class CompanyGate extends StatefulWidget {
  const CompanyGate({super.key, required this.auth, required this.user});

  final AuthService auth;
  final User user;

  @override
  State<CompanyGate> createState() => _CompanyGateState();
}

class _CompanyGateState extends State<CompanyGate> {
  final _service = CompanyOfflineFirstService();
  final _model = CompanyModel();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final active = await _service.getActiveLocalCompany(uid: widget.user.uid);
    if (active != null) {
      _model.setActive(companyId: active.$1, companyName: active.$2);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createCompany(String name) async {
    final ent = EntitlementsScope.of(context);
    final companyId = await _service.createCompanyOfflineFirst(
      companyName: name,
      ent: ent,
    );
    _model.setActive(companyId: companyId, companyName: name);
  }

  Future<void> _sync() async {
    final ent = EntitlementsScope.of(context);
    await _service.syncActiveCompany(ent: ent);
  }

  Future<void> _editCompanyName() async {
    final ent = EntitlementsScope.of(context);

    final newName = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EditCompanyNamePage(initialName: _model.companyName),
      ),
    );

    if (newName == null) return;

    // local-first + cloud si Plus/Pro
    await _service.renameActiveCompany(newName: newName, ent: ent);

    // 🔥 actualiza UI en tiempo real (sin reiniciar)
    _model.setActive(companyId: _model.companyId, companyName: newName);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_model.hasCompany) {
      return CreateCompanyPage(onCreate: _createCompany);
    }

    return CompanyScope(
      notifier: _model,
      child: HomePage(
        auth: widget.auth,
        user: widget.user,
        onSyncPressed: _sync,
        onEditCompanyName: _editCompanyName,
      ),
    );
  }
}
