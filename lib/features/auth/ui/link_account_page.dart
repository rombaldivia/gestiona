import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_service.dart';

class LinkAccountPage extends StatefulWidget {
  const LinkAccountPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<LinkAccountPage> createState() => _LinkAccountPageState();
}

class _LinkAccountPageState extends State<LinkAccountPage> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();

  bool _busyGoogle = false;
  bool _busyEmail = false;

  @override
  void dispose() {
    _emailC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  Future<void> _linkGoogle() async {
    setState(() => _busyGoogle = true);
    try {
      await widget.auth.signInWithGoogle();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta vinculada con Google.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo vincular Google: $e')));
    } finally {
      if (mounted) setState(() => _busyGoogle = false);
    }
  }

  Future<void> _linkEmail() async {
    final email = _emailC.text.trim();
    final password = _passwordC.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa correo y contraseña.')),
      );
      return;
    }

    setState(() => _busyEmail = true);
    try {
      await widget.auth.registerWithEmail(email: email, password: password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta vinculada con correo.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo vincular correo: $e')));
    } finally {
      if (mounted) setState(() => _busyEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Vincular cuenta')),
      body: SafeArea(
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
                  Text(
                    'Ya estás dentro de una empresa',
                    style: AppTextStyles.title,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu sesión actual es temporal. Vincula tu cuenta para no perder acceso a la empresa más adelante.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'UID actual: ${user?.uid ?? '-'}',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _busyGoogle ? null : _linkGoogle,
                    icon: const Icon(Icons.login),
                    label: Text(
                      _busyGoogle ? 'Vinculando...' : 'Vincular con Google',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('O vincular con correo', style: AppTextStyles.title),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailC,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordC,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busyEmail ? null : _linkEmail,
                    icon: const Icon(Icons.link),
                    label: Text(
                      _busyEmail ? 'Vinculando...' : 'Vincular con correo',
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
