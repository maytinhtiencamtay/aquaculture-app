class User {
  final String id;
  final String email;
  final String displayName;
  final String token;
  final String? storeName;
  final String? phone;
  final String? address;
  final String? storeId;
  final String role;
  final List<String> permissions;

  User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.token,
    this.storeName,
    this.phone,
    this.address,
    this.storeId,
    this.role = 'owner',
    this.permissions = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String? ?? '',
      token: json['token'] as String,
      storeName: json['storeName'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      storeId: json['storeId'] as String?,
      role: json['role'] as String? ?? 'owner',
      permissions: (json['permissions'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'token': token,
      'role': role,
      'permissions': permissions,
      if (storeName != null) 'storeName': storeName,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (storeId != null) 'storeId': storeId,
    };
  }

  bool get isOwner => role == 'owner';

  bool hasPermission(String permission) {
    if (isOwner) return true;
    // Granular check: 'ponds.view', 'ponds.create', etc.
    if (permission.contains('.')) return permissions.contains(permission);
    // Module-level check (for navigation): check if module.view exists
    // Also support legacy permissions without action suffix
    return permissions.contains('$permission.view') || permissions.contains(permission);
  }

  bool canView(String module) => hasPermission('$module.view');
  bool canCreate(String module) => hasPermission('$module.create');
  bool canEdit(String module) => hasPermission('$module.edit');
  bool canDelete(String module) => hasPermission('$module.delete');

  String get roleLabel {
    switch (role) {
      case 'owner': return 'Chủ cửa hàng';
      case 'manager': return 'Quản lý';
      case 'technician': return 'Kỹ thuật viên';
      case 'worker': return 'Công nhân';
      default: return role;
    }
  }
}

class AppPermissions {
  static const dashboard = 'dashboard';
  static const farmMap = 'farm_map';
  static const tasks = 'tasks';
  static const reports = 'reports';
  static const warehouse = 'warehouse';
  static const products = 'products';
  static const ponds = 'ponds';
  static const batches = 'batches';
  static const staff = 'staff';
  static const sales = 'sales';
  static const branches = 'branches';
  static const customers = 'customers';
  static const settings = 'settings';
  static const accounts = 'accounts';

  // CRUD actions
  static const view = 'view';
  static const create = 'create';
  static const edit = 'edit';
  static const delete = 'delete';

  static const List<String> actions = [view, create, edit, delete];

  static const Map<String, String> actionLabels = {
    view: 'Xem',
    create: 'Thêm',
    edit: 'Sửa',
    delete: 'Xóa',
  };

  static const Map<String, String> labels = {
    dashboard: 'Tổng quan',
    farmMap: 'Sơ đồ trại',
    tasks: 'Công việc',
    reports: 'Báo cáo',
    warehouse: 'Kho',
    products: 'Hàng hóa',
    ponds: 'Ao nuôi',
    batches: 'Lô cá',
    staff: 'Nhân sự',
    sales: 'Bán hàng',
    branches: 'Chi nhánh',
    customers: 'Khách hàng',
    settings: 'Cài đặt',
    accounts: 'Quản lý tài khoản',
  };

  /// Modules that support all CRUD actions
  static const List<String> crudModules = [
    ponds, batches, warehouse, products, staff, sales,
    branches, customers, tasks,
  ];

  /// Modules that only support view
  static const List<String> viewOnlyModules = [
    dashboard, farmMap, reports, settings, accounts,
  ];

  static const List<String> all = [
    dashboard, farmMap, tasks, reports, warehouse, products,
    ponds, batches, staff, sales, branches, customers, settings, accounts,
  ];

  /// Build permission key like 'ponds.view'
  static String key(String module, String action) => '$module.$action';

  /// Get all granular permissions for a module
  static List<String> allForModule(String module) {
    if (viewOnlyModules.contains(module)) return ['$module.view'];
    return actions.map((a) => '$module.$a').toList();
  }

  /// Get all granular permissions
  static List<String> get allGranular {
    final result = <String>[];
    for (final m in all) {
      result.addAll(allForModule(m));
    }
    return result;
  }

  static List<String> forRole(String role) {
    switch (role) {
      case 'owner':
        return allGranular;
      case 'manager':
        final result = <String>[];
        for (final m in all) {
          if (m == accounts) continue;
          result.addAll(allForModule(m));
        }
        return result;
      case 'technician':
        final mods = [dashboard, farmMap, tasks, ponds, batches, warehouse];
        final result = <String>[];
        for (final m in mods) {
          if (viewOnlyModules.contains(m)) {
            result.add('$m.view');
          } else {
            result.addAll(['$m.view', '$m.edit']);
          }
        }
        return result;
      case 'worker':
        return ['$dashboard.view', '$tasks.view'];
      default:
        return ['$dashboard.view'];
    }
  }
}
