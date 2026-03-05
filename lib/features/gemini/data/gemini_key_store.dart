import 'package:shared_preferences/shared_preferences.dart';

class GeminiKeyStore {
  static const _key = 'gemini_api_key_v1';

  Future<String?> load() async {
    final sp = await SharedPreferences.getInstance();
    final v  = sp.getString(_key);
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  Future<void> save(String key) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, key.trim());
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }
}
