import 'package:flutter/material.dart';
import '../../auth/data/auth_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.auth, required this.companyId});
  final AuthService auth;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestiona'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: auth.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Empresa activa: $companyId\n\nSesión iniciada ✅',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
