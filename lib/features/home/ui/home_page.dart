import 'package:flutter/material.dart';
import '../../auth/data/auth_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: auth.signOut,
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: const Center(child: Text('Sesión iniciada ✅')),
    );
  }
}
