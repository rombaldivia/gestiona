import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import 'home_page.dart';
import 'statistics_page.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({
    super.key,
    required this.auth,
    required this.user,
    required this.onSyncPressed,
    required this.onEditCompanyName,
  });

  final AuthService auth;
  final User user;
  final Future<void> Function() onSyncPressed;
  final Future<void> Function() onEditCompanyName;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(
            auth: widget.auth,
            user: widget.user,
            onSyncPressed: widget.onSyncPressed,
            onEditCompanyName: widget.onEditCompanyName,
          ),
          const StatisticsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Estadísticas',
          ),
        ],
      ),
    );
  }
}
