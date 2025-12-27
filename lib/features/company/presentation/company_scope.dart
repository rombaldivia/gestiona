import 'package:flutter/widgets.dart';

class CompanyModel extends ChangeNotifier {
  String? _companyId;
  String? _companyName;

  bool get hasCompany => _companyId != null && _companyName != null;

  String get companyId => _companyId ?? '-';
  String get companyName => _companyName ?? 'Sin empresa';

  void setActive({required String companyId, required String companyName}) {
    _companyId = companyId;
    _companyName = companyName;
    notifyListeners();
  }

  void clear() {
    _companyId = null;
    _companyName = null;
    notifyListeners();
  }
}

class CompanyScope extends InheritedNotifier<CompanyModel> {
  const CompanyScope({
    super.key,
    required CompanyModel notifier,
    required Widget child,
  }) : super(notifier: notifier, child: child);

  static CompanyModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CompanyScope>();
    assert(scope != null, 'CompanyScope no encontrado en el árbol de widgets.');
    return scope!.notifier!;
  }
}
