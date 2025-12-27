import 'package:shared_preferences/shared_preferences.dart';

class LocalCompanyStore {
  static const _kActiveCompanyId = 'activeCompanyId';
  static const _kActiveCompanyName = 'activeCompanyName';

  Future<(String? id, String? name)> readActiveCompany() async {
    final sp = await SharedPreferences.getInstance();
    final id = sp.getString(_kActiveCompanyId);
    final name = sp.getString(_kActiveCompanyName);
    return (id, name);
  }

  Future<void> saveActiveCompany({required String id, required String name}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kActiveCompanyId, id);
    await sp.setString(_kActiveCompanyName, name);
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kActiveCompanyId);
    await sp.remove(_kActiveCompanyName);
  }
}
