import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_service.dart';

/// Instancia de AuthService para inyección por toda la app.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Stream global del estado de autenticación.
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.authStateChanges();
});
