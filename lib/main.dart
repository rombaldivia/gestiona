import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/ui/login_page.dart';
import 'features/company/presentation/company_gate.dart';
import 'features/subscription/presentation/entitlements_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth      = ref.watch(authServiceProvider);
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestiona',
      theme: AppTheme.light,

      // ✅ El scope envuelve TODAS las rutas del Navigator raíz
      builder: (context, child) {
        final w = child ?? const SizedBox.shrink();
        return authState.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error de autenticación: $e'),
              ),
            ),
          ),
          data: (user) {
            if (user == null) return w;
            return EntitlementsGate(user: user, child: w);
          },
        );
      },

      // ✅ Home según sesión
      home: authState.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error de autenticación: $e'),
            ),
          ),
        ),
        data: (User? user) {
          if (user == null) return LoginPage(auth: auth);
          return CompanyGate(auth: auth, user: user);
        },
      ),
    );
  }
}
