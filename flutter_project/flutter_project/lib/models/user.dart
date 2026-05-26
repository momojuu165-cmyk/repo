bool _parseBool(dynamic v, {bool defaultValue = false}) {
  if (v == null) return defaultValue;
  if (v is bool) return v;
  if (v is int) return v == 1;
  return defaultValue;
}

// Feature 3: codeType (permanent/temporary) + codeExpiry
class User {
    final int? id;
    final String username;
    final String passwordHash;
    final String role;
    final String name;
    final String? phone;
    final List<String> permissions;
    final int? partnerGroupId;
    final bool isActive;
    final bool mustChangePassword;
    final String? loginCode;
    final String? departmentType;
    final String codeType;
    final String? codeExpiry;
    final String createdAt;
    final String? allowedPriceTier;

    User({
      this.id,
      required this.username,
      required this.passwordHash,
      required this.role,
      required this.name,
      this.phone,
      this.permissions = const [],
      this.partnerGroupId,
      this.isActive = true,
      this.mustChangePassword = false,
      this.loginCode,
      this.departmentType,
      this.codeType = 'permanent',
      this.codeExpiry,
      required this.createdAt,
      this.allowedPriceTier,
    });

    bool get isCodeExpired {
      if (codeType == 'permanent') return false;
      if (codeExpiry == null) return false;
      return DateTime.now().isAfter(DateTime.parse(codeExpiry!));
    }

    bool hasPermission(String perm) =>
        role == 'admin' || role == 'system_admin' || role == 'manager' || permissions.contains(perm);

    bool canAccessDept(String dept) {
      if (role == 'admin') return true;
      if (departmentType == null || departmentType == 'all') return true;
      return departmentType == dept;
    }

    bool get canViewPartners =>
        role == 'admin' || hasPermission('view_partners');

    Map<String, dynamic> toMap() => {
          'id': id,
          'username': username,
          'password_hash': passwordHash,
          'role': role,
          'name': name,
          'phone': phone,
          'permissions': permissions.join(','),
          'partner_group_id': partnerGroupId,
          'is_active': isActive,
          'must_change_password': mustChangePassword,
          'login_code': loginCode,
          'department_type': departmentType,
          'code_type': codeType,
          'code_expiry': codeExpiry,
          'created_at': createdAt,
          'allowed_price_tier': allowedPriceTier,
        };

    factory User.fromMap(Map<String, dynamic> m) => User(
          id: m['id'] as int?,
          username: m['username'] as String,
          passwordHash: m['password_hash'] as String,
          role: m['role'] as String,
          name: m['name'] as String,
          phone: m['phone'] as String?,
          permissions: _parsePermissions(m['permissions'] as String?),
          partnerGroupId: m['partner_group_id'] as int?,
          isActive: _parseBool(m['is_active'], defaultValue: true),
          mustChangePassword: _parseBool(m['must_change_password']),
          loginCode: m['login_code'] as String?,
          departmentType: m['department_type'] as String?,
          codeType: m['code_type'] as String? ?? 'permanent',
          codeExpiry: m['code_expiry'] as String?,
          createdAt: m['created_at'] as String,
          allowedPriceTier: m['allowed_price_tier'] as String?,
        );

    static List<String> _parsePermissions(String? raw) {
      if (raw == null || raw.isEmpty) return [];
      return raw.split(',').where((s) => s.isNotEmpty).toList();
    }

    User copyWith({
      int? id,
      String? username,
      String? passwordHash,
      String? role,
      String? name,
      String? phone,
      List<String>? permissions,
      int? partnerGroupId,
      bool? isActive,
      bool? mustChangePassword,
      String? loginCode,
      String? departmentType,
      String? codeType,
      String? codeExpiry,
      String? createdAt,
      String? allowedPriceTier,
    }) =>
        User(
          id: id ?? this.id,
          username: username ?? this.username,
          passwordHash: passwordHash ?? this.passwordHash,
          role: role ?? this.role,
          name: name ?? this.name,
          phone: phone ?? this.phone,
          permissions: permissions ?? this.permissions,
          partnerGroupId: partnerGroupId ?? this.partnerGroupId,
          isActive: isActive ?? this.isActive,
          mustChangePassword: mustChangePassword ?? this.mustChangePassword,
          loginCode: loginCode ?? this.loginCode,
          departmentType: departmentType ?? this.departmentType,
          codeType: codeType ?? this.codeType,
          codeExpiry: codeExpiry ?? this.codeExpiry,
          createdAt: createdAt ?? this.createdAt,
          allowedPriceTier: allowedPriceTier ?? this.allowedPriceTier,
        );
  }
