import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../../company/presentation/company_scope.dart';
import '../../subscription/presentation/entitlements_scope.dart';
import '../../inventory/ui/inventory_page.dart';
import '../../quotes/ui/quotes_tabs_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({
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

  Future<void> _signOut() async => auth.signOut();

  void _todo(BuildContext context, String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label (pendiente de conectar)')));
  }

  @override
  Widget build(BuildContext context) {
    final ent = EntitlementsScope.of(context);
    final company = CompanyScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          company.companyName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => _todo(context, 'Notificaciones'),
            icon: const Icon(Icons.notifications_none),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) async {
              if (v == 'edit_company') {
                await onEditCompanyName();
              } else if (v == 'sync') {
                if (!ent.cloudSync) {
                  _todo(context, 'Sync (requiere Plus/Pro)');
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Sincronizando...')),
                );
                try {
                  await onSyncPressed();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Sync OK ✅')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Sync falló: $e')),
                  );
                }
              } else if (v == 'logout') {
                await _signOut();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit_company',
                child: Text('Editar empresa'),
              ),
              PopupMenuItem(
                value: 'sync',
                enabled: ent.cloudSync,
                child: Text(ent.cloudSync ? 'Sync ahora' : 'Sync (Plus/Pro)'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ent.cloudSync ? 'Sincronización activa' : 'Modo local',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text('Hoy', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 12),

          // Grid 2x2
          Row(
            children: [
              Expanded(
                child: _PremiumCard(
                  variant: _CardVariant.quotesBlue,
                  title: 'Cotizaciones',
                  subtitle: 'Hoy: 2 pendientes',
                  buttonText: 'Crear cotización',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QuotesTabsPage()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PremiumCard(
                  variant: _CardVariant.workPurple,
                  title: 'Órdenes\nde trabajo',
                  subtitle: 'En proceso: 5',
                  buttonText: 'Ver órdenes',
                  onPressed: () => _todo(context, 'Órdenes de trabajo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PremiumCard(
                  variant: _CardVariant.inventoryGreen,
                  title: 'Inventario',
                  subtitle: 'Stock y movimientos',
                  buttonText: 'Ver stock',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const InventoryPage()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PremiumCard(
                  variant: _CardVariant.billingOrange,
                  title: 'Facturación',
                  subtitle: 'Por cobrar hoy: 2',
                  buttonText: 'Impuestos',
                  onPressed: () => _todo(context, 'Impuestos'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Flujo de trabajo
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flujo de trabajo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 12),
                  _FlowItem(time: '09:30', text: 'COT-1023 aprobada'),
                  _FlowItem(time: '09:50', text: 'OT-231 en producción'),
                  _FlowItem(time: '10:15', text: 'FAC-2010 pagada'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _CardVariant { quotesBlue, workPurple, inventoryGreen, billingOrange }

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({
    required this.variant,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  final _CardVariant variant;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color titleColor;
    Color subColor;
    Color buttonBg;
    Color buttonFg;

    // Colores “por módulo” (como antes)
    switch (variant) {
      case _CardVariant.quotesBlue:
        bg = const Color(0xFF2F6DAE).withValues(alpha: 0.10);
        border = const Color(0xFF2F6DAE).withValues(alpha: 0.25);
        titleColor = const Color(0xFF2F6DAE);
        subColor = const Color(0xFF2F6DAE).withValues(alpha: 0.75);
        buttonBg = const Color(0xFF2F6DAE);
        buttonFg = Colors.white;
        break;

      case _CardVariant.workPurple:
        bg = const Color(0xFF3E5C76).withValues(alpha: 0.10);
        border = const Color(0xFF3E5C76).withValues(alpha: 0.25);
        titleColor = const Color(0xFF3E5C76);
        subColor = const Color(0xFF3E5C76).withValues(alpha: 0.75);
        buttonBg = const Color(0xFF3E5C76);
        buttonFg = Colors.white;
        break;

      case _CardVariant.inventoryGreen:
        bg = const Color(0xFF2A6F6B).withValues(alpha: 0.10);
        border = const Color(0xFF2A6F6B).withValues(alpha: 0.25);
        titleColor = const Color(0xFF2A6F6B);
        subColor = const Color(0xFF2A6F6B).withValues(alpha: 0.75);
        buttonBg = const Color(0xFF2A6F6B);
        buttonFg = Colors.white;
        break;

      case _CardVariant.billingOrange:
        bg = const Color(0xFF495867).withValues(alpha: 0.10);
        border = const Color(0xFF495867).withValues(alpha: 0.25);
        titleColor = const Color(0xFF495867);
        subColor = const Color(0xFF495867).withValues(alpha: 0.75);
        buttonBg = const Color(0xFF495867);
        buttonFg = Colors.white;
        break;
    }

    return Card(
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          height: 128,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(fontSize: 12, color: subColor)),
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: buttonBg,
                    foregroundColor: buttonFg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onPressed,
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowItem extends StatelessWidget {
  const _FlowItem({required this.time, required this.text});
  final String time;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(time, style: t.bodySmall)),
          Expanded(child: Text(text, style: t.bodyMedium)),
        ],
      ),
    );
  }
}
