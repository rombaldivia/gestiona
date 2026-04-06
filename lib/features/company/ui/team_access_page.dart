import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../subscription/presentation/entitlements_providers.dart';
import '../data/company_access_service.dart';
import '../domain/company_member.dart';
import '../presentation/company_providers.dart';
import '../presentation/company_scope.dart';
import 'qr_join_scanner_page.dart';

class TeamAccessPage extends ConsumerStatefulWidget {
  const TeamAccessPage({super.key});

  @override
  ConsumerState<TeamAccessPage> createState() => _TeamAccessPageState();
}

class _TeamAccessPageState extends ConsumerState<TeamAccessPage> {
  final CompanyAccessService _service = CompanyAccessService();
  final TextEditingController _joinCodeController = TextEditingController();

  bool _loadingOwner = true;
  bool _isOwner = false;
  bool _busyGenerate = false;
  bool _busyJoin = false;
  String _selectedRole = companyJoinRoles.last;
  JoinCodeData? _activeCode;
  String? _companyId;
  String? _companyName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final scope = CompanyScope.of(context);
    final companyId = scope.companyId;
    final companyName = scope.companyName;

    final isOwner = await _service.isCurrentUserOwner(companyId);
    final activeCode = isOwner
        ? await _service.getActiveJoinCode(companyId: companyId)
        : null;

    if (!mounted) return;
    setState(() {
      _companyId = companyId;
      _companyName = companyName;
      _isOwner = isOwner;
      _activeCode = activeCode;
      _selectedRole = activeCode?.role ?? companyJoinRoles.last;
      _loadingOwner = false;
    });
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _generateQr() async {
    if (_companyId == null || _companyName == null) return;

    setState(() => _busyGenerate = true);
    try {
      final code = await _service.createJoinCode(
        companyId: _companyId!,
        companyName: _companyName!,
        role: _selectedRole,
      );
      if (!mounted) return;
      setState(() => _activeCode = code);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo generar el QR: $e')));
    } finally {
      if (mounted) setState(() => _busyGenerate = false);
    }
  }

  Future<void> _pasteCode() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    _joinCodeController.text = text;
    if (mounted) setState(() {});
  }

  Future<void> _scanCode() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrJoinScannerPage()),
    );
    final text = raw?.trim() ?? '';
    if (!mounted || text.isEmpty) return;
    _joinCodeController.text = text;
    setState(() {});
    await _joinCompany();
  }

  Future<String?> _askNameIfNeeded() async {
    final current = FirebaseAuth.instance.currentUser;
    final currentName = (current?.displayName ?? '').trim();
    if (currentName.isNotEmpty) return currentName;

    final c = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tu nombre'),
        content: TextField(
          controller: c,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej: Juan Pérez',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    final name = (result ?? '').trim();
    if (name.isEmpty) return null;
    return name;
  }

  Future<void> _joinCompany() async {
    final raw = _joinCodeController.text.trim();
    if (raw.isEmpty) return;

    setState(() => _busyJoin = true);
    try {
      final preferredName = await _askNameIfNeeded();
      if (!mounted) return;
      if (preferredName == null) {
        setState(() => _busyJoin = false);
        return;
      }

      final joined = await _service.joinWithCode(
        raw,
        preferredName: preferredName,
      );
      if (!mounted) return;
      _joinCodeController.clear();
      ref.invalidate(companyControllerProvider);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        ref.invalidate(entitlementsProvider(uid));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ahora perteneces a ${joined.companyName} como ${companyRoleLabel(joined.role)}.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo unir a la empresa: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyJoin = false);
    }
  }

  Future<void> _changeRole(CompanyMember member) async {
    if (_companyId == null) return;

    String selected = member.role;

    final role = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cambiar rol'),
        content: StatefulBuilder(
          builder: (context, setLocal) {
            return DropdownButtonFormField<String>(
              initialValue: selected,
              items: companyJoinRoles
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(companyRoleLabel(r)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setLocal(() => selected = v);
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (role == null) return;

    try {
      await _service.updateMemberRole(
        companyId: _companyId!,
        memberUid: member.uid,
        role: role,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rol actualizado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el rol: $e')),
      );
    }
  }

  Future<void> _editPermissions(CompanyMember member) async {
    if (_companyId == null) return;

    var perms = member.permissions;

    final updated = await showDialog<MemberModulePermissions>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Permisos de ${member.name.isEmpty ? member.uid : member.name}',
        ),
        content: SizedBox(
          width: 380,
          child: StatefulBuilder(
            builder: (context, setLocal) {
              Widget field(
                String label,
                String value,
                void Function(String) onChanged,
              ) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: value,
                    decoration: InputDecoration(labelText: label),
                    items: moduleAccessLevels
                        .map<DropdownMenuItem<String>>(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(moduleAccessLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() => onChanged(v));
                    },
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Dashboard siempre visible para cualquier miembro.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  field(
                    'Cotizaciones',
                    perms.quotes,
                    (v) => perms = perms.copyWith(quotes: v),
                  ),
                  field(
                    'OT',
                    perms.workOrders,
                    (v) => perms = perms.copyWith(workOrders: v),
                  ),
                  field(
                    'Inventario',
                    perms.inventory,
                    (v) => perms = perms.copyWith(inventory: v),
                  ),
                  field(
                    'Ventas',
                    perms.sales,
                    (v) => perms = perms.copyWith(sales: v),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, perms),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (updated == null) return;

    try {
      await _service.updateMemberPermissions(
        companyId: _companyId!,
        memberUid: member.uid,
        permissions: updated,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Permisos actualizados.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron actualizar permisos: $e')),
      );
    }
  }

  Future<void> _removeMember(CompanyMember member) async {
    if (_companyId == null) return;

    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Eliminar acceso'),
            content: Text(
              '¿Quitar a ${member.name.isEmpty ? member.uid : member.name} de la empresa?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    try {
      await _service.removeMember(
        companyId: _companyId!,
        memberUid: member.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Miembro eliminado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar al miembro: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Equipo y acceso QR')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_companyId == null || _companyName == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Equipo y acceso QR')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No hay una empresa activa todavía.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Equipo y acceso QR')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _InfoCard(
            title: 'Cómo funciona',
            icon: Icons.groups_2_outlined,
            child: const Text(
              'El dueño genera un QR temporal. El empleado puede pegar el código o escanearlo con la cámara para quedar agregado a la empresa con el rol elegido.',
            ),
          ),
          const SizedBox(height: 16),
          if (_isOwner) ...[
            _OwnerQrCard(
              selectedRole: _selectedRole,
              activeCode: _activeCode,
              busy: _busyGenerate,
              onRoleChanged: (value) {
                if (value == null) return;
                setState(() => _selectedRole = value);
              },
              onGenerate: _generateQr,
            ),
            const SizedBox(height: 16),
            _MembersCard(
              service: _service,
              companyId: _companyId!,
              onChangeRole: _changeRole,
              onEditPermissions: _editPermissions,
              onRemove: _removeMember,
            ),
            const SizedBox(height: 16),
          ],
          _JoinCard(
            controller: _joinCodeController,
            busy: _busyJoin,
            onPaste: _pasteCode,
            onScan: _scanCode,
            onJoin: _joinCompany,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.title),
                  const SizedBox(height: 8),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerQrCard extends StatelessWidget {
  const _OwnerQrCard({
    required this.selectedRole,
    required this.activeCode,
    required this.busy,
    required this.onRoleChanged,
    required this.onGenerate,
  });

  final String selectedRole;
  final JoinCodeData? activeCode;
  final bool busy;
  final ValueChanged<String?> onRoleChanged;
  final Future<void> Function() onGenerate;

  @override
  Widget build(BuildContext context) {
    final qrText = activeCode == null
        ? null
        : '{"code":"${activeCode!.code}","companyId":"${activeCode!.companyId}","role":"${activeCode!.role}"}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Generar QR de acceso', style: AppTextStyles.title),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedRole,
              items: companyJoinRoles
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(companyRoleLabel(role)),
                    ),
                  )
                  .toList(),
              onChanged: busy ? null : onRoleChanged,
              decoration: const InputDecoration(
                labelText: 'Rol del invitado',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : onGenerate,
              icon: const Icon(Icons.qr_code_2_rounded),
              label: Text(busy ? 'Generando...' : 'Generar / renovar QR'),
            ),
            if (activeCode != null) ...[
              const SizedBox(height: 16),
              Center(child: QrImageView(data: qrText!, size: 220)),
              const SizedBox(height: 12),
              SelectableText(activeCode!.code, style: AppTextStyles.title),
              const SizedBox(height: 4),
              Text(
                'Rol: ${companyRoleLabel(activeCode!.role)}',
                style: AppTextStyles.body,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({
    required this.service,
    required this.companyId,
    required this.onChangeRole,
    required this.onEditPermissions,
    required this.onRemove,
  });

  final CompanyAccessService service;
  final String companyId;
  final Future<void> Function(CompanyMember member) onChangeRole;
  final Future<void> Function(CompanyMember member) onEditPermissions;
  final Future<void> Function(CompanyMember member) onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<CompanyMember>>(
          stream: service.watchMembers(companyId: companyId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final members = snap.data!;
            if (members.isEmpty) {
              return const Text('Todavía no hay miembros en la empresa.');
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Miembros del equipo', style: AppTextStyles.title),
                const SizedBox(height: 12),
                ...members.map(
                  (m) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name.isEmpty ? 'Sin nombre' : m.name,
                            style: AppTextStyles.title,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m.email.isEmpty ? 'Sin correo' : m.email,
                            style: AppTextStyles.body,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text(companyRoleLabel(m.role))),
                              if (m.isAnonymous)
                                const Chip(label: Text('Temporal')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cotizaciones: ${moduleAccessLabel(m.permissions.quotes)}',
                          ),
                          Text(
                            'OT: ${moduleAccessLabel(m.permissions.workOrders)}',
                          ),
                          Text(
                            'Inventario: ${moduleAccessLabel(m.permissions.inventory)}',
                          ),
                          Text(
                            'Ventas: ${moduleAccessLabel(m.permissions.sales)}',
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => onChangeRole(m),
                                icon: const Icon(
                                  Icons.manage_accounts_outlined,
                                ),
                                label: const Text('Cambiar rol'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => onEditPermissions(m),
                                icon: const Icon(Icons.tune_outlined),
                                label: const Text('Permisos'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => onRemove(m),
                                icon: const Icon(Icons.person_remove_outlined),
                                label: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _JoinCard extends StatelessWidget {
  const _JoinCard({
    required this.controller,
    required this.busy,
    required this.onPaste,
    required this.onScan,
    required this.onJoin,
  });

  final TextEditingController controller;
  final bool busy;
  final Future<void> Function() onPaste;
  final Future<void> Function() onScan;
  final Future<void> Function() onJoin;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unirme con QR o código', style: AppTextStyles.title),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Código o texto del QR',
                prefixIcon: Icon(Icons.qr_code_2_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onPaste,
                  icon: const Icon(Icons.content_paste_go_outlined),
                  label: const Text('Pegar'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onScan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Escanear'),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : onJoin,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(busy ? 'Uniendo...' : 'Unirme'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
