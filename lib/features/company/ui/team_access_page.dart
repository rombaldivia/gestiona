import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../data/company_access_service.dart';
import '../domain/company_member.dart';
import '../presentation/company_scope.dart';
import '../presentation/company_providers.dart';
import '../../subscription/presentation/entitlements_providers.dart';
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

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final company = CompanyScope.maybeOf(context);

    if (company == null) {
      if (!mounted) return;
      setState(() {
        _companyId = null;
        _companyName = null;
        _loadingOwner = false;
        _isOwner = false;
        _activeCode = null;
      });
      return;
    }

    _companyId = company.companyId;
    _companyName = company.companyName;
    await _load();
  }

  Future<void> _load() async {
    final companyId = _companyId;
    if (companyId == null) return;

    try {
      final isOwner = await _service.isCurrentUserOwner(companyId);
      JoinCodeData? code;
      if (isOwner) {
        code = await _service.getActiveJoinCode(companyId: companyId);
      }
      if (!mounted) return;
      setState(() {
        _isOwner = isOwner;
        _activeCode = code;
        if (code != null && companyJoinRoles.contains(code.role)) {
          _selectedRole = code.role;
        }
        _loadingOwner = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingOwner = false;
      });
    }
  }

  Future<void> _generateQr() async {
    final companyId = _companyId;
    final companyName = _companyName;

    if (companyId == null || companyName == null) return;

    setState(() => _busyGenerate = true);
    try {
      final code = await _service.createJoinCode(
        companyId: companyId,
        companyName: companyName,
        role: _selectedRole,
      );
      if (!mounted) return;
      setState(() => _activeCode = code);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QR de acceso generado.')));
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

  Future<void> _joinCompany() async {
    final raw = _joinCodeController.text.trim();
    if (raw.isEmpty) return;

    setState(() => _busyJoin = true);
    try {
      final joined = await _service.joinWithCode(raw);
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
            _MembersCard(service: _service, companyId: _companyId!),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(title, style: AppTextStyles.title),
              ],
            ),
            const SizedBox(height: 12),
            child,
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
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Text('Generar QR para empleados', style: AppTextStyles.title),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedRole,
              items: companyJoinRoles
                  .map(
                    (role) => DropdownMenuItem<String>(
                      value: role,
                      child: Text(companyRoleLabel(role)),
                    ),
                  )
                  .toList(),
              onChanged: busy ? null : onRoleChanged,
              decoration: const InputDecoration(labelText: 'Rol del ingreso'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onGenerate,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(busy ? 'Generando...' : 'Generar / renovar QR'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cada renovación invalida el QR anterior.',
              style: AppTextStyles.label,
            ),
            if (activeCode != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: QrImageView(
                    data: activeCode!.code,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: SelectableText(
                  _formatCode(activeCode!.code),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    label: Text('Rol: ${companyRoleLabel(activeCode!.role)}'),
                  ),
                  if (activeCode!.expiresAt != null)
                    Chip(
                      label: Text(
                        'Expira: ${_formatDateTime(activeCode!.expiresAt!)}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: activeCode!.code),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código copiado.')),
                    );
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copiar código'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCode(String code) {
    final chars = code.trim();
    if (chars.length <= 4) return chars;
    final parts = <String>[];
    for (var i = 0; i < chars.length; i += 4) {
      parts.add(
        chars.substring(i, i + 4 > chars.length ? chars.length : i + 4),
      );
    }
    return parts.join(' ');
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.service, required this.companyId});

  final CompanyAccessService service;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Text('Miembros actuales', style: AppTextStyles.title),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<CompanyMember>>(
              stream: service.watchMembers(companyId: companyId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final members = snap.data ?? const <CompanyMember>[];
                if (members.isEmpty) {
                  return const Text('Todavía no hay empleados agregados.');
                }

                return Column(
                  children: [
                    for (final member in members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(
                            member.name.isNotEmpty
                                ? member.name[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(
                          member.name.isEmpty ? 'Sin nombre' : member.name,
                        ),
                        subtitle: Text(
                          member.email.isEmpty
                              ? companyRoleLabel(member.role)
                              : '${member.email} · ${companyRoleLabel(member.role)}',
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
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
            Row(
              children: [
                const Icon(Icons.login_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Text('Unirme a una empresa', style: AppTextStyles.title),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Código o texto del QR',
                hintText: 'Ej: A1B2C3D4E5F6',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onPaste,
                  icon: const Icon(Icons.content_paste_go_outlined),
                  label: const Text('Pegar'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onScan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Escanear QR'),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : onJoin,
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(busy ? 'Uniendo...' : 'Unirme'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'También puedes abrir la cámara y leer el QR directamente.',
              style: AppTextStyles.label,
            ),
          ],
        ),
      ),
    );
  }
}
