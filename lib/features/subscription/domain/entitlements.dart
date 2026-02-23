import 'plan_tier.dart';

class Entitlements {
  final PlanTier tier;

  const Entitlements._(this.tier);

  factory Entitlements.forTier(PlanTier tier) => Entitlements._(tier);

  // Feature gates (solo FREE/PRO)
  bool get cloudSync => tier == PlanTier.pro;
  bool get multiCompany => tier == PlanTier.pro; // Free: 1 empresa
  bool get rolesAndTeams => tier == PlanTier.pro;

  bool get whatsappIntegration => tier == PlanTier.pro;
  bool get advancedReports => tier == PlanTier.pro;

  // ✅ NUEVO: USD protector y PDF en cotizaciones
  bool get usdProtector => tier == PlanTier.pro;
  bool get quotePdfShare => tier == PlanTier.pro;

  // Límites
  int get maxCompanies => switch (tier) {
    PlanTier.free => 1,
    PlanTier.pro => 999999,
  };

  int get maxTeamMembers => switch (tier) {
    PlanTier.free => 1,
    PlanTier.pro => 999999,
  };
}
