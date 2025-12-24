import 'package:flutter/widgets.dart';
import '../domain/entitlements.dart';

class EntitlementsScope extends InheritedWidget {
  const EntitlementsScope({
    super.key,
    required this.entitlements,
    required super.child,
  });

  final Entitlements entitlements;

  static Entitlements of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<EntitlementsScope>();
    assert(scope != null, 'EntitlementsScope no está arriba en el árbol.');
    return scope!.entitlements;
  }

  @override
  bool updateShouldNotify(covariant EntitlementsScope oldWidget) =>
      oldWidget.entitlements.tier != entitlements.tier;
}
