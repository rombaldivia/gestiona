import 'package:shared_preferences/shared_preferences.dart';

class PendingJoinStore {
  static const _key = 'pendingJoinCode';

  Future<String?> getCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key)?.trim();
    if (code == null || code.isEmpty) return null;
    return code;
  }

  Future<void> saveCode(String rawCode) async {
    final prefs = await SharedPreferences.getInstance();
    final code = rawCode.trim();
    if (code.isEmpty) {
      await prefs.remove(_key);
      return;
    }
    await prefs.setString(_key, code);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
