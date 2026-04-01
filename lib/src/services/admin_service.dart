import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

class AdminUser {
  final String id;
  final String email;
  final String name;
  final String role;
  final String token;

  AdminUser({required this.id, required this.email, required this.name, required this.role, required this.token});

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String? ?? '',
      role: json['role'] as String,
      token: json['token'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'name': name, 'role': role, 'token': token};
}

class AdminService {
  static const _storageKey = 'aqua_admin';

  final FlutterSecureStorage _secureStorage;
  final ApiService _apiService;

  AdminService({FlutterSecureStorage? secureStorage, ApiService? apiService})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _apiService = apiService ?? ApiService();

  Future<AdminUser?> getCachedAdmin() async {
    final stored = await _secureStorage.read(key: _storageKey);
    if (stored == null) return null;
    final json = jsonDecode(stored) as Map<String, dynamic>;
    final admin = AdminUser.fromJson(json);
    _apiService.setToken(admin.token);
    return admin;
  }

  Future<({AdminUser? admin, String? error})> login({required String email, required String password}) async {
    final response = await _apiService.post('/sysadmin/login', body: {'email': email, 'password': password});
    if (response.statusCode != 200) {
      final msg = (response.data is Map) ? response.data['message'] as String? : null;
      return (admin: null, error: msg ?? 'Đăng nhập thất bại');
    }
    final admin = AdminUser.fromJson(response.data as Map<String, dynamic>);
    _apiService.setToken(admin.token);
    await _secureStorage.write(key: _storageKey, value: jsonEncode(admin.toJson()));
    return (admin: admin, error: null);
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: _storageKey);
    _apiService.setToken(null);
  }

  // Dashboard
  Future<Map<String, dynamic>?> getDashboard() async {
    final resp = await _apiService.get('/sysadmin/dashboard');
    if (resp.statusCode == 200) return resp.data as Map<String, dynamic>;
    return null;
  }

  // Stores
  Future<List<Map<String, dynamic>>> getStores() async {
    final resp = await _apiService.get('/sysadmin/stores');
    if (resp.statusCode == 200) return (resp.data as List).cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>?> getStoreDetail(String id) async {
    final resp = await _apiService.get('/sysadmin/stores/$id');
    if (resp.statusCode == 200) return resp.data as Map<String, dynamic>;
    return null;
  }

  Future<bool> updateStoreStatus(String storeId, String status) async {
    final resp = await _apiService.put('/sysadmin/stores/$storeId/status', body: {'status': status});
    return resp.statusCode == 200;
  }

  // Licenses
  Future<List<Map<String, dynamic>>> getLicenses() async {
    final resp = await _apiService.get('/sysadmin/licenses');
    if (resp.statusCode == 200) return (resp.data as List).cast<Map<String, dynamic>>();
    return [];
  }

  Future<({Map<String, dynamic>? license, String? error})> createLicense({
    required String storeId,
    required String plan,
    required int durationDays,
    String? note,
  }) async {
    final resp = await _apiService.post('/sysadmin/licenses', body: {
      'storeId': storeId,
      'plan': plan,
      'durationDays': durationDays,
      if (note != null) 'note': note,
    });
    if (resp.statusCode == 201) return (license: resp.data as Map<String, dynamic>, error: null);
    final msg = (resp.data is Map) ? resp.data['message'] as String? : null;
    return (license: null, error: msg ?? 'Tạo license thất bại');
  }

  Future<bool> deleteLicense(String id) async {
    final resp = await _apiService.delete('/sysadmin/licenses/$id');
    return resp.statusCode == 200;
  }
}
