import 'package:flutter/widgets.dart';

class CompanyScope extends InheritedWidget {
  final String companyId;
  final String companyName;

  const CompanyScope({
    super.key,
    required this.companyId,
    required this.companyName,
    required super.child,
  });

  static CompanyScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CompanyScope>();
  }

  static CompanyScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'CompanyScope no está arriba en el árbol.');
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant CompanyScope oldWidget) {
    return companyId != oldWidget.companyId ||
        companyName != oldWidget.companyName;
  }
}
