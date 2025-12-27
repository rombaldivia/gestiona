import 'plan_tier.dart';

class Entitlements {
  final PlanTier tier;

  const Entitlements._(this.tier);

  factory Entitlements.forTier(PlanTier tier) => Entitlements._(tier);

  // Feature gates
  bool get cloudSync => tier != PlanTier.free;
  bool get multiCompany => tier != PlanTier.free; // Free: 1 empresa
  bool get rolesAndTeams => tier == PlanTier.pro;

  bool get whatsappIntegration => tier == PlanTier.pro;
  bool get advancedReports => tier == PlanTier.pro;

  // Límites
  int get maxCompanies => switch (tier) {
    PlanTier.free => 1,
    PlanTier.plus => 3,
    PlanTier.pro => 999999,
  };

  int get maxTeamMembers => switch (tier) {
    PlanTier.free => 1,
    PlanTier.plus => 3,
    PlanTier.pro => 999999,
  };
}
