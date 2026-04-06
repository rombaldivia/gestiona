import '../domain/company_member.dart';

bool canViewModule(MemberModulePermissions p, String module) {
  final value = _moduleValue(p, module);
  return value == 'view' || value == 'edit';
}

bool canEditModule(MemberModulePermissions p, String module) {
  final value = _moduleValue(p, module);
  return value == 'edit';
}

String _moduleValue(MemberModulePermissions p, String module) {
  switch (module) {
    case 'quotes':
      return p.quotes;
    case 'workOrders':
      return p.workOrders;
    case 'inventory':
      return p.inventory;
    case 'sales':
      return p.sales;
    default:
      return 'none';
  }
}
