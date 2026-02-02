import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SyncMode { local, cloud }

const _kPrefKey = 'sync_mode';

class SyncModeController extends AsyncNotifier<SyncMode> {
  @override
  Future<SyncMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefKey);
    return raw == 'cloud' ? SyncMode.cloud : SyncMode.local;
  }

  Future<void> setMode(SyncMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    state = AsyncData(mode);
    await prefs.setString(_kPrefKey, mode == SyncMode.cloud ? 'cloud' : 'local');
  }

  Future<void> toggle() async {
    final current = state.value ?? SyncMode.local;
    final next = current == SyncMode.local ? SyncMode.cloud : SyncMode.local;
    await setMode(next);
  }
}

final syncModeProvider =
    AsyncNotifierProvider<SyncModeController, SyncMode>(SyncModeController.new);
