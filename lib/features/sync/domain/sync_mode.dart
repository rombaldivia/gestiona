enum SyncMode { local, active }

extension SyncModeX on SyncMode {
  String get label =>
      this == SyncMode.local ? 'Modo local' : 'Sincronización activa';
  bool get isActive => this == SyncMode.active;

  static SyncMode fromString(String? v) {
    return v == 'active' ? SyncMode.active : SyncMode.local;
  }

  String get asString => this == SyncMode.active ? 'active' : 'local';
}
