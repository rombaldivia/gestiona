class CompanyMember {
  const CompanyMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAtMs,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final int joinedAtMs;

  factory CompanyMember.fromJson(Map<String, dynamic> json) {
    return CompanyMember(
      uid: (json['uid'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      email: (json['email'] as String? ?? '').trim(),
      role: (json['role'] as String? ?? 'operario').trim(),
      joinedAtMs: (json['joinedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

const companyJoinRoles = <String>['admin', 'vendedor', 'operario'];

String companyRoleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'Admin';
    case 'vendedor':
      return 'Vendedor';
    case 'operario':
      return 'Operario';
    default:
      return role;
  }
}
