import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_service.dart';
import '../../home/ui/home_page.dart';
import '../../subscription/presentation/entitlements_scope.dart';
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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  bool _booting = true;
  String? _companyId;
  String? _companyName;

  String get _kId => 'activeCompanyId_${widget.user.uid}';
  String get _kName => 'activeCompanyName_${widget.user.uid}';

  @override
  void initState() {
    super.initState();
    _loadLocalThenListenCloud();
  }

  Future<void> _loadLocalThenListenCloud() async {
    // 1) Local first
    final prefs = await SharedPreferences.getInstance();
    final localId = prefs.getString(_kId);
    final localName = prefs.getString(_kName);

    if (mounted && localId != null && localName != null) {
      setState(() {
        _companyId = localId;
        _companyName = localName;
        _booting = false;
      });
    } else {
      if (mounted) {
        setState(() => _booting = false);
      }
    }

    // 2) Cloud realtime (si existe doc, actualiza y guarda local)
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .snapshots()
        .listen((snap) async {
          final data = snap.data();
          if (data == null) return;

          final cid = data['activeCompanyId'] as String?;
          final cname = data['activeCompanyName'] as String?;

          if (cid != null && cname != null) {
            final prefs2 = await SharedPreferences.getInstance();
            await prefs2.setString(_kId, cid);
            await prefs2.setString(_kName, cname);

            if (!mounted) return;
            setState(() {
              _companyId = cid;
              _companyName = cname;
            });
          }
        });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _createCompany(String name) async {
    final ent = EntitlementsScope.of(context);

    final companyId = await _service.createCompanyOfflineFirst(
      companyName: name,
      ent: ent,
    );

    // guarda local inmediato (para Free también)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kId, companyId);
    await prefs.setString(_kName, name);

    if (!mounted) return;
    setState(() {
      _companyId = companyId;
      _companyName = name;
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
    if (_companyId == null) return;

    // 1) Local update
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, newName);

    if (!mounted) return;
    setState(() => _companyName = newName);

    // 2) Cloud update (solo Plus/Pro)
    if (ent.cloudSync) {
      final now = FieldValue.serverTimestamp();
      final cid = _companyId!;

      await FirebaseFirestore.instance.collection('companies').doc(cid).set({
        'name': newName,
        'updatedAt': now,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .set({
            'activeCompanyName': newName,
            'updatedAt': now,
          }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // si no hay empresa, crear
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
