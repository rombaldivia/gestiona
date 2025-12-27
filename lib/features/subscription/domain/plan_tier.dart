enum PlanTier {
  free,
  plus,
  pro;

  static PlanTier fromString(String? value) {
    switch ((value ?? '').toLowerCase().trim()) {
      case 'plus':
        return PlanTier.plus;
      case 'pro':
        return PlanTier.pro;
      case 'free':
      default:
        return PlanTier.free;
    }
  }

  String get asString => switch (this) {
    PlanTier.free => 'free',
    PlanTier.plus => 'plus',
    PlanTier.pro => 'pro',
  };
}
