class CompanyState {
  const CompanyState({this.companyId, this.companyName});

  final String? companyId;
  final String? companyName;

  bool get hasCompany => companyId != null && companyName != null;
}
