import 'package:flutter/material.dart';
import '../data/auth_service.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});
  final AuthService auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: cs.primary.withAlpha((0.12 * 255).round()),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.business, color: cs.primary),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gestiona',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Inicia sesión para continuar',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _loading
                              ? null
                              : () => _run(
                                  () async => widget.auth.signInWithGoogle(),
                                ),
                          icon: const Icon(Icons.g_mobiledata),
                          label: const Text('Continuar con Google'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 10),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Correo',
                                hintText: 'tucorreo@ejemplo.com',
                              ),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Correo inválido'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pass,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Contraseña',
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Mínimo 6 caracteres'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _loading
                                    ? null
                                    : () => _run(() async {
                                        if (!_formKey.currentState!.validate())
                                          return;
                                        await widget.auth.signInWithEmail(
                                          email: _email.text.trim(),
                                          password: _pass.text.trim(),
                                        );
                                      }),
                                child: _loading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(),
                                      )
                                    : const Text('Entrar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ForgotPasswordPage(
                                          auth: widget.auth,
                                        ),
                                      ),
                                    );
                                  },
                            child: const Text('Recuperar contraseña'),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            RegisterPage(auth: widget.auth),
                                      ),
                                    );
                                  },
                            child: const Text('Crear cuenta'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
