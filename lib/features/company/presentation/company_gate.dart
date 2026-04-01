import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_service.dart';
import '../../home/ui/home_shell_page.dart';
import '../../subscription/presentation/entitlements_scope.dart';
import '../data/company_access_service.dart';
import '../data/pending_join_store.dart';
import 'company_providers.dart';
import 'company_scope.dart';
import 'company_state.dart';

class CompanyGate extends ConsumerWidget {
  const CompanyGate({super.key, required this.auth, required this.user});

  final AuthService auth;
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCompany = ref.watch(companyControllerProvider);

    return asyncCompany.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error cargando empresa: $e'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.read(companyControllerProvider.notifier).reload(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (company) {
        final ent = EntitlementsScope.of(context);
        final ctrl = ref.read(companyControllerProvider.notifier);

        Future<void> editCompanyName() async {
          final current = company.companyName ?? '';
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
          await ctrl.renameActiveCompany(newName: newName, ent: ent);
        }

        return _PendingJoinResolver(
          auth: auth,
          user: user,
          company: company,
          onCreate: (name) => ctrl.createCompany(name: name, ent: ent),
          onJoin: (code) => CompanyAccessService().joinWithCode(code),
          onReload: () => ctrl.reload(),
          onSyncPressed: () => ctrl.syncNow(ent: ent),
          onEditCompanyName: editCompanyName,
        );
      },
    );
  }
}

class _PendingJoinResolver extends StatefulWidget {
  const _PendingJoinResolver({
    required this.auth,
    required this.user,
    required this.company,
    required this.onCreate,
    required this.onJoin,
    required this.onReload,
    required this.onSyncPressed,
    required this.onEditCompanyName,
  });

  final AuthService auth;
  final User user;
  final CompanyState company;
  final Future<void> Function(String name) onCreate;
  final Future<void> Function(String code) onJoin;
  final Future<void> Function() onReload;
  final Future<void> Function() onSyncPressed;
  final Future<void> Function() onEditCompanyName;

  @override
  State<_PendingJoinResolver> createState() => _PendingJoinResolverState();
}

class _PendingJoinResolverState extends State<_PendingJoinResolver> {
  final _store = PendingJoinStore();

  bool _booting = true;
  bool _hasPendingInvite = false;
  String? _joinError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolvePendingJoin();
    });
  }

  Future<void> _resolvePendingJoin() async {
    try {
      final code = await _store.getCode();

      if (code == null || code.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _booting = false;
          _hasPendingInvite = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _hasPendingInvite = true;
        _joinError = null;
      });

      await widget.onJoin(code.trim());
      await _store.clear();
      await widget.onReload();

      if (!mounted) return;
      setState(() {
        _booting = false;
        _hasPendingInvite = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _booting = false;
        _hasPendingInvite = true;
        _joinError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting || _hasPendingInvite) {
      if (_joinError != null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Error de invitación')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No se pudo completar la invitación de empresa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(_joinError!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          await widget.auth.signOut();
                        },
                        child: const Text('Volver'),
                      ),
                      FilledButton.tonal(
                        onPressed: () async {
                          await _store.clear();
                          if (!mounted) return;
                          setState(() {
                            _hasPendingInvite = false;
                            _joinError = null;
                          });
                        },
                        child: const Text('Continuar sin invitación'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Ingresando a la empresa...', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.company.hasCompany) {
      return CompanyScope(
        companyId: widget.company.companyId!,
        companyName: widget.company.companyName!,
        child: HomeShellPage(
          auth: widget.auth,
          user: widget.user,
          onSyncPressed: widget.onSyncPressed,
          onEditCompanyName: widget.onEditCompanyName,
        ),
      );
    }

    return _CreateCompanyScreen(user: widget.user, onCreate: widget.onCreate);
  }
}

class _CreateCompanyScreen extends StatefulWidget {
  const _CreateCompanyScreen({required this.user, required this.onCreate});

  final User user;
  final Future<void> Function(String name) onCreate;

  @override
  State<_CreateCompanyScreen> createState() => _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends State<_CreateCompanyScreen> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final email = (widget.user.email ?? '').trim();
    final seed = email.isNotEmpty ? email.split('@').first : 'Mi empresa';
    _controller.text = seed;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() => _busy = true);
    try {
      await widget.onCreate(name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la empresa: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear empresa')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              const Text(
                'Todavía no tienes una empresa activa.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Crea una empresa para empezar a usar Gestiona.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _busy ? null : _submit(),
                decoration: const InputDecoration(
                  labelText: 'Nombre de la empresa',
                  hintText: 'Ej: Hermenca',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: const Icon(Icons.add_business_outlined),
                label: Text(_busy ? 'Creando...' : 'Crear empresa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
