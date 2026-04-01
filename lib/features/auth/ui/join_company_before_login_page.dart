import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../company/data/company_access_service.dart';
import '../../company/data/pending_join_store.dart';
import '../../company/presentation/company_providers.dart';
import '../../subscription/presentation/entitlements_providers.dart';
import '../data/auth_service.dart';
import 'qr_scanner_page.dart';

class JoinCompanyBeforeLoginPage extends ConsumerStatefulWidget {
  const JoinCompanyBeforeLoginPage({super.key, required this.auth});

  final AuthService auth;

  @override
  ConsumerState<JoinCompanyBeforeLoginPage> createState() =>
      _JoinCompanyBeforeLoginPageState();
}

class _JoinCompanyBeforeLoginPageState
    extends ConsumerState<JoinCompanyBeforeLoginPage> {
  final _store = PendingJoinStore();
  final _service = CompanyAccessService();
  final _controller = TextEditingController();

  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final current = await _store.getCode();
    if (!mounted) return;
    _controller.text = current ?? '';
    setState(() => _loading = false);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    _controller.text = text;
    if (mounted) setState(() {});
  }

  Future<void> _scan() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    final text = raw?.trim() ?? '';
    if (!mounted || text.isEmpty) return;
    _controller.text = text;
    setState(() {});
  }

  Future<void> _continueJoin() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pega, escribe o escanea el código del QR.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await widget.auth.signInAnonymously();
      }

      final joined = await _service.joinWithCode(code);
      await _store.clear();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      ref.invalidate(companyControllerProvider);
      if (uid != null) {
        ref.invalidate(entitlementsProvider(uid));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Te uniste a ${joined.companyName} como ${joined.role}.',
          ),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo unir a la empresa: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    await _store.clear();
    if (!mounted) return;
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Unirme a una empresa')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadows.card,
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Código de empresa', style: AppTextStyles.title),
                        const SizedBox(height: 8),
                        Text(
                          signedIn
                              ? 'Escanea el QR o pega el código y al continuar entrarás directo a la empresa.'
                              : 'Escanea el QR o pega el código. Al continuar se creará una sesión temporal y entrarás directo a la empresa.',
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _controller,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Código o texto del QR',
                            hintText: 'Ej: A1B2C3D4E5F6',
                            prefixIcon: Icon(Icons.qr_code_2_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _paste,
                              icon: const Icon(Icons.content_paste_go_outlined),
                              label: const Text('Pegar'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _scan,
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: const Text('Escanear QR'),
                            ),
                            if (_controller.text.trim().isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _clear,
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Borrar'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _continueJoin,
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                            ),
                            label: Text(_busy ? 'Procesando...' : 'Continuar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
