class Employee {
  final String id;
  final String name;
  final String email;
  final String role;
  final String phone;
  final String branchId;
  final String shift;
  final bool hasAccount;
  final List<String> permissions;
  final DateTime createdAt;

  Employee({
    required this.id,
    required this.name,
    this.email = '',
    this.role = 'worker',
    this.phone = '',
    this.branchId = '',
    this.shift = '',
    this.hasAccount = false,
    this.permissions = const [],
    required this.createdAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'worker',
    phone: json['phone'] as String? ?? '',
    branchId: json['branchId'] as String? ?? '',
    shift: json['shift'] as String? ?? '',
    hasAccount: json['hasAccount'] as bool? ?? false,
    permissions: (json['permissions'] as List<dynamic>?)?.cast<String>() ?? [],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'role': role,
    'phone': phone,
    'branchId': branchId,
    'shift': shift,
    'hasAccount': hasAccount,
    'permissions': permissions,
  };

  String get roleLabel => roleToLabel(role);

  static const defaultRoles = <String, String>{
    'owner': 'Chủ cửa hàng',
    'manager': 'Quản lý',
    'technician': 'Kỹ thuật',
    'worker': 'Công nhân',
  };

  static String roleToLabel(String role) => defaultRoles[role] ?? role;

  static String labelToRole(String label) {
    for (final e in defaultRoles.entries) {
      if (e.value == label) return e.key;
    }
    return label;
  }
}
