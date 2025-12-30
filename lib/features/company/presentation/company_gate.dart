import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_service.dart';
import '../../home/ui/home_page.dart';
import '../../subscription/presentation/entitlements_scope.dart';
import '../data/company_local_store.dart';
import '../data/company_offline_first_service.dart';
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
  final _local = CompanyLocalStore();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  bool _booting = true;
  String? _companyId;
  String? _companyName;

  // Legacy keys (se usaban antes directo en SharedPreferences).
  // Los mantenemos para migrar y para no romper instalaciones existentes.
  String get _legacyIdKey => 'activeCompanyId_${widget.user.uid}';
  String get _legacyNameKey => 'activeCompanyName_${widget.user.uid}';

  @override
  void initState() {
    super.initState();
    _loadLocalThenListenCloud();
  }

  Future<void> _loadLocalThenListenCloud() async {
    // 1) Local (nuevo storage)
    final local = await _service.getActiveLocalCompany(uid: widget.user.uid);

    // 2) Si no hay en nuevo storage, intenta migrar desde legacy prefs
    if (local == null) {
      final prefs = await SharedPreferences.getInstance();
      final legacyId = prefs.getString(_legacyIdKey);
      final legacyName = prefs.getString(_legacyNameKey);

      if (legacyId != null && legacyName != null) {
        await _local.setActiveCompany(uid: widget.user.uid, id: legacyId, name: legacyName);
        if (mounted) {
          setState(() {
            _companyId = legacyId;
            _companyName = legacyName;
            _booting = false;
          });
        }
      } else {
        if (mounted) setState(() => _booting = false);
      }
    } else {
      if (mounted) {
        setState(() {
          _companyId = local.$1;
          _companyName = local.$2;
          _booting = false;
        });
      }
    }

    // 3) Cloud realtime: si existe doc, actualiza local (y opcionalmente legacy)
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .snapshots()
        .listen((snap) async {
      final data = snap.data();
      if (data == null) return;

      final cid = data['activeCompanyId'] as String?;
      final cname = data['activeCompanyName'] as String?;
      if (cid == null || cname == null) return;

      // Guarda a storage nuevo
      await _local.setActiveCompany(uid: widget.user.uid, id: cid, name: cname);

      // Mantén legacy actualizado (por compatibilidad)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_legacyIdKey, cid);
      await prefs.setString(_legacyNameKey, cname);

      if (!mounted) return;
      setState(() {
        _companyId = cid;
        _companyName = cname;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _createCompany(String name) async {
    final ent = EntitlementsScope.of(context);

    await _service.createCompanyOfflineFirst(
      companyName: name,
      ent: ent,
    );

    // Lee desde storage nuevo (fuente de verdad)
    final local = await _service.getActiveLocalCompany(uid: widget.user.uid);
    if (local == null) return;

    // Mantén legacy actualizado
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_legacyIdKey, local.$1);
    await prefs.setString(_legacyNameKey, local.$2);

    if (!mounted) return;
    setState(() {
      _companyId = local.$1;
      _companyName = local.$2;
    });
  }

  Future<void> _syncNow() async {
    final ent = EntitlementsScope.of(context);
    if (!ent.cloudSync) return;

    await _service.syncActiveCompany(ent: ent);
  }

  Future<void> _editCompanyName() async {
    final ent = EntitlementsScope.of(context);

    final current = _companyName ?? '';
    final controller = TextEditingController(text: current);

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar nombre de empresa'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej: Hermenca',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              Navigator.pop(context, v.isEmpty ? null : v);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newName == null) return;

    // Renombra usando el servicio (local-first; nube solo Pro)
    await _service.renameActiveCompany(newName: newName, ent: ent);

    // Relee desde storage nuevo
    final local = await _service.getActiveLocalCompany(uid: widget.user.uid);
    if (local == null) return;

    // Mantén legacy actualizado
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_legacyIdKey, local.$1);
    await prefs.setString(_legacyNameKey, local.$2);

    if (!mounted) return;
    setState(() {
      _companyId = local.$1;
      _companyName = local.$2;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_companyId == null || _companyName == null) {
      return _CreateCompanyInline(onCreate: _createCompany);
    }

    return CompanyScope(
      companyId: _companyId!,
      companyName: _companyName!,
      child: HomePage(
        auth: widget.auth,
        user: widget.user,
        onSyncPressed: _syncNow,
        onEditCompanyName: _editCompanyName,
      ),
    );
  }
}

class _CreateCompanyInline extends StatefulWidget {
  const _CreateCompanyInline({required this.onCreate});

  final Future<void> Function(String name) onCreate;

  @override
  State<_CreateCompanyInline> createState() => _CreateCompanyInlineState();
}

class _CreateCompanyInlineState extends State<_CreateCompanyInline> {
  final _c = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _c.text.trim();
    if (name.isEmpty) return;

    setState(() => _loading = true);
    try {
      await widget.onCreate(name);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
              controller: _c,
              decoration: const InputDecoration(
                labelText: 'Nombre de la empresa',
                hintText: 'Ej: Hermenca',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? 'Creando...' : 'Crear'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
