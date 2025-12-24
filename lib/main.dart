import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'features/auth/data/auth_service.dart';
import 'features/auth/ui/login_page.dart';
import 'features/company/data/company_service.dart';
import 'features/company/ui/company_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final companyService = CompanyService();

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2F6DAE), // azul calmado
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestiona',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0.8,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.all(0),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD7E1EE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD7E1EE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        dividerTheme: const DividerThemeData(
          thickness: 1,
          space: 24,
          color: Color(0xFFE6EEF7),
        ),
      ),
      home: AuthGate(auth: auth, companyService: companyService),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.auth, required this.companyService});
  final AuthService auth;
  final CompanyService companyService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: auth.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) return LoginPage(auth: auth);
        return CompanyGate(auth: auth, companyService: companyService);
      },
    );
  }
}
