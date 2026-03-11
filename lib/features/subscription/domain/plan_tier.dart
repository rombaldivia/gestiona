enum PlanTier {
  free,
  pro;

  static PlanTier fromString(String? value) {
    switch ((value ?? '').toLowerCase().trim()) {
      case 'pro':
        return PlanTier.pro;
      case 'free':
      default:
        return PlanTier.free;
    }
  }

  String get asString => switch (this) {
    PlanTier.free => 'free',
    PlanTier.pro => 'pro',
  };
}
