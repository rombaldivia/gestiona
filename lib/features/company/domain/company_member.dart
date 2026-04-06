const companyJoinRoles = ['admin', 'vendedor', 'operario'];

const moduleAccessLevels = ['none', 'view', 'edit'];

String companyRoleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'Administrador';
    case 'vendedor':
      return 'Vendedor';
    case 'operario':
      return 'Operario';
    default:
      return role;
  }
}

String moduleAccessLabel(String value) {
  switch (value) {
    case 'none':
      return 'Sin acceso';
    case 'view':
      return 'Ver';
    case 'edit':
      return 'Editar';
    default:
      return value;
  }
}

class MemberModulePermissions {
  const MemberModulePermissions({
    required this.quotes,
    required this.workOrders,
    required this.inventory,
    required this.sales,
  });

  final String quotes;
  final String workOrders;
  final String inventory;
  final String sales;

  factory MemberModulePermissions.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};

    String read(String key) {
      final value = (j[key] as String? ?? 'none').trim();
      return moduleAccessLevels.contains(value) ? value : 'none';
    }

    return MemberModulePermissions(
      quotes: read('quotes'),
      workOrders: read('workOrders'),
      inventory: read('inventory'),
      sales: read('sales'),
    );
  }

  Map<String, dynamic> toJson() => {
    'quotes': quotes,
    'workOrders': workOrders,
    'inventory': inventory,
    'sales': sales,
  };

  MemberModulePermissions copyWith({
    String? quotes,
    String? workOrders,
    String? inventory,
    String? sales,
  }) {
    return MemberModulePermissions(
      quotes: quotes ?? this.quotes,
      workOrders: workOrders ?? this.workOrders,
      inventory: inventory ?? this.inventory,
      sales: sales ?? this.sales,
    );
  }
}

MemberModulePermissions permissionsForRole(String role) {
  switch (role) {
    case 'admin':
      return const MemberModulePermissions(
        quotes: 'edit',
        workOrders: 'edit',
        inventory: 'edit',
        sales: 'edit',
      );
    case 'vendedor':
      return const MemberModulePermissions(
        quotes: 'edit',
        workOrders: 'view',
        inventory: 'view',
        sales: 'edit',
      );
    case 'operario':
    default:
      return const MemberModulePermissions(
        quotes: 'none',
        workOrders: 'edit',
        inventory: 'view',
        sales: 'none',
      );
  }
}

class CompanyMember {
  const CompanyMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAtMs,
    required this.isAnonymous,
    required this.permissions,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final int joinedAtMs;
  final bool isAnonymous;
  final MemberModulePermissions permissions;

  factory CompanyMember.fromJson(Map<String, dynamic> json) {
    return CompanyMember(
      uid: (json['uid'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      email: (json['email'] as String? ?? '').trim(),
      role: (json['role'] as String? ?? 'operario').trim(),
      joinedAtMs: (json['joinedAtMs'] as num?)?.toInt() ?? 0,
      isAnonymous: json['isAnonymous'] == true,
      permissions: MemberModulePermissions.fromJson(
        json['permissions'] as Map<String, dynamic>?,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'email': email,
    'role': role,
    'joinedAtMs': joinedAtMs,
    'isAnonymous': isAnonymous,
    'permissions': permissions.toJson(),
  };

  CompanyMember copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    int? joinedAtMs,
    bool? isAnonymous,
    MemberModulePermissions? permissions,
  }) {
    return CompanyMember(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      joinedAtMs: joinedAtMs ?? this.joinedAtMs,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      permissions: permissions ?? this.permissions,
    );
  }
}
