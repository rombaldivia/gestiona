import 'package:flutter/widgets.dart';

import '../domain/entitlements.dart';
import '../domain/plan_tier.dart';

class EntitlementsScope extends InheritedWidget {
  const EntitlementsScope({
    super.key,
    required this.entitlements,
    required super.child,
  });

  final Entitlements entitlements;

  /// Devuelve null si no hay EntitlementsScope arriba (NO crashea).
  static Entitlements? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<EntitlementsScope>();
    return scope?.entitlements;
  }

  /// Devuelve FREE por defecto si no existe EntitlementsScope arriba (evita pantalla roja).
  static Entitlements of(BuildContext context) {
    return maybeOf(context) ?? Entitlements.forTier(PlanTier.free);
  }

  @override
  bool updateShouldNotify(covariant EntitlementsScope oldWidget) {
    return oldWidget.entitlements != entitlements;
  }
}
