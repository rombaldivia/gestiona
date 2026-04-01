import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gestiona_logo.dart';
import '../data/auth_service.dart';
import '../../company/data/pending_join_store.dart';
import '../../company/data/company_access_service.dart';
import 'link_account_page.dart';
import 'forgot_password_page.dart';
import '../../company/data/company_local_store.dart';
import 'join_company_before_login_page.dart';
import 'register_page.dart';

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
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
      await _consumePendingJoinIfNeeded();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _consumePendingJoinIfNeeded() async {
    final store = PendingJoinStore();
    final code = await store.getCode();
    if (code == null || code.isEmpty) return;
    try {
      await CompanyAccessService().joinWithCode(code);
      await store.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Te uniste a la empresa correctamente.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo unir: \$e')));
    }
  }

  Future<bool> _maybeLinkInsteadOfLogin() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null || !current.isAnonymous) return false;

    final local = await CompanyLocalStore().getActiveCompany(uid: current.uid);
    if (local == null) return false;
    if (!mounted) return true;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LinkAccountPage(auth: widget.auth)),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 52),
              Center(child: const GestionaLogoLockup()),
              const SizedBox(height: 40),
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
                    Text('Iniciar sesión', style: AppTextStyles.title),
                    const SizedBox(height: 4),
                    Text('Bienvenido de vuelta', style: AppTextStyles.body),
                    const SizedBox(height: 20),
                    _GoogleButton(
                      loading: _loading,
                      onTap: () => _run(() async {
                        final redirected = await _maybeLinkInsteadOfLogin();
                        if (redirected) return;
                        await widget.auth.signInWithGoogle();
                      }),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o con correo',
                            style: AppTextStyles.label,
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              hintText: 'tucorreo@ejemplo.com',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Correo inválido'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _pass,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Mínimo 6 caracteres'
                                : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ForgotPasswordPage(
                                          auth: widget.auth,
                                        ),
                                      ),
                                    ),
                              child: const Text('¿Olvidaste tu contraseña?'),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _loading
                                  ? null
                                  : () => _run(() async {
                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }
                                      final redirected =
                                          await _maybeLinkInsteadOfLogin();
                                      if (redirected) return;
                                      await widget.auth.signInWithEmail(
                                        email: _email.text.trim(),
                                        password: _pass.text.trim(),
                                      );
                                    }),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Entrar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¿No tienes cuenta? ', style: AppTextStyles.body),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegisterPage(auth: widget.auth),
                            ),
                          ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Crear cuenta',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _loading
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                JoinCompanyBeforeLoginPage(auth: widget.auth),
                          ),
                        ),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Unirme a una empresa sin correo'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border, width: 1.2),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Image.asset(
                'assets/brand/google_g_logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Continuar con Google',
              style: AppTextStyles.label.copyWith(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
