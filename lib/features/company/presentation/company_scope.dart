import 'package:flutter/material.dart';

class CompanyScope extends InheritedWidget {
  const CompanyScope({
    super.key,
    required this.companyId,
    required this.companyName,
    required super.child,
  });

  final String companyId;
  final String companyName;

  static CompanyScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CompanyScope>();
    assert(scope != null, 'CompanyScope no está arriba en el árbol.');
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant CompanyScope oldWidget) {
    return companyId != oldWidget.companyId ||
        companyName != oldWidget.companyName;
  }
}
