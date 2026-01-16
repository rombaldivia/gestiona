import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../../company/presentation/company_scope.dart';
import '../../subscription/presentation/entitlements_scope.dart';
import '../../inventory/ui/inventory_page.dart';

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
          // Header suave (subtítulo pequeño)
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

          // Grid 2x2 premium moderno
          Row(
            children: [
              Expanded(
                child: _PremiumCard(
                  variant: _CardVariant.primary,
                  title: 'Cotizaciones',
                  subtitle: 'Hoy: 2 pendientes',
                  buttonText: 'Crear cotización',
                  onPressed: () => _todo(context, 'Cotizaciones'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PremiumCard(
                  variant: _CardVariant.accent,
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
                  variant: _CardVariant.neutral,
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
                  variant: _CardVariant.neutral,
                  title: 'Facturación',
                  subtitle: 'Por cobrar hoy: 2',
                  buttonText: 'Impuestos',
                  onPressed: () => _todo(context, 'Impuestos'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Flujo de trabajo (simple, premium)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
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

enum _CardVariant { primary, accent, neutral }

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
    final scheme = Theme.of(context).colorScheme;

    Color bg;
    Color border;
    Color titleColor;
    Color subColor;
    Color buttonBg;
    Color buttonFg;

    switch (variant) {
      case _CardVariant.primary:
        bg = scheme.primaryContainer.withValues(alpha: 0.85);
        border = scheme.primary.withValues(alpha: 0.18);
        titleColor = scheme.onPrimaryContainer;
        subColor = scheme.onPrimaryContainer.withValues(alpha: 0.85);
        buttonBg = scheme.primary;
        buttonFg = scheme.onPrimary;
        break;
      case _CardVariant.accent:
        bg = scheme.tertiaryContainer.withValues(alpha: 0.85);
        border = scheme.tertiary.withValues(alpha: 0.18);
        titleColor = scheme.onTertiaryContainer;
        subColor = scheme.onTertiaryContainer.withValues(alpha: 0.85);
        buttonBg = scheme.tertiary;
        buttonFg = scheme.onTertiary;
        break;
      case _CardVariant.neutral:
        bg = scheme.surfaceContainerHighest.withValues(alpha: 0.55);
        border = Colors.black.withValues(alpha: 0.08);
        titleColor = scheme.onSurface;
        subColor = scheme.onSurfaceVariant;
        buttonBg = scheme.primary;
        buttonFg = scheme.onPrimary;
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
                  fontSize: 15,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(fontSize: 12.5, color: subColor)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonBg,
                    foregroundColor: buttonFg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
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
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              time,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
