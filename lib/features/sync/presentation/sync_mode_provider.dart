import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/sync_mode.dart';

const _kSyncModeKey = 'sync_mode';

class SyncModeController extends AsyncNotifier<SyncMode> {
  @override
  Future<SyncMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return SyncModeX.fromString(prefs.getString(_kSyncModeKey));
  }

  Future<void> setMode(SyncMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSyncModeKey, mode.asString);
    state = AsyncData(mode);
  }

  Future<void> toggle() async {
    final current = state.value ?? SyncMode.local;
    final next = current == SyncMode.local ? SyncMode.active : SyncMode.local;
    await setMode(next);
  }
}

final syncModeProvider =
    AsyncNotifierProvider<SyncModeController, SyncMode>(SyncModeController.new);
