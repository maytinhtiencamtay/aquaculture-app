import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  static const _storageKey = 'aqua_user';

  final FlutterSecureStorage _secureStorage;
  final ApiService _apiService;

  AuthService({FlutterSecureStorage? secureStorage, ApiService? apiService})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _apiService = apiService ?? ApiService();

  Future<User?> getCachedUser() async {
    final stored = await _secureStorage.read(key: _storageKey);
    if (stored == null) return null;
    final json = jsonDecode(stored) as Map<String, dynamic>;
    return User.fromJson(json);
  }

  Future<({User? user, String? error})> signIn({required String email, required String password}) async {
    final response = await _apiService.post('/auth/login', body: {
      'email': email,
      'password': password,
    });

    if (response.statusCode != 200) {
      final msg = (response.data is Map) ? response.data['message'] as String? : null;
      return (user: null, error: msg ?? 'Đăng nhập thất bại');
    }

    final raw = response.data as Map<String, dynamic>;
    final user = User.fromJson(raw);
    await _secureStorage.write(key: _storageKey, value: jsonEncode(user.toJson()));
    return (user: user, error: null);
  }

  Future<({User? user, String? error})> signUp({
    required String storeName,
    String? email,
    String? phone,
    String? address,
    required String password,
  }) async {
    final response = await _apiService.post('/auth/register', body: {
      'storeName': storeName,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (address != null && address.isNotEmpty) 'address': address,
      'password': password,
    });

    if (response.statusCode != 201) {
      final msg = (response.data is Map) ? response.data['message'] as String? : null;
      return (user: null, error: msg ?? 'Đăng ký thất bại');
    }

    final raw = response.data as Map<String, dynamic>;
    final user = User.fromJson(raw);
    await _secureStorage.write(key: _storageKey, value: jsonEncode(user.toJson()));
    return (user: user, error: null);
  }

  Future<String?> forgotPassword({required String email}) async {
    final response = await _apiService.post('/auth/forgot-password', body: {'email': email});
    final msg = (response.data is Map) ? response.data['message'] as String? : null;
    if (response.statusCode != 200) return msg ?? 'Không thể gửi mã xác nhận';
    return null;
  }

  Future<String?> resetPassword({required String email, required String code, required String newPassword}) async {
    final response = await _apiService.post('/auth/reset-password', body: {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
    final msg = (response.data is Map) ? response.data['message'] as String? : null;
    if (response.statusCode != 200) return msg ?? 'Đổi mật khẩu thất bại';
    return null;
  }

  Future<void> signOut() async {
    await _secureStorage.delete(key: _storageKey);
  }

  // ── Store User Account Management ──

  Future<({bool success, String? error})> createStoreUser({
    required String employeeId,
    String? email,
    String? phone,
    required String password,
    required String role,
    required List<String> permissions,
  }) async {
    final response = await _apiService.post('/store-users', body: {
      'employeeId': employeeId,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'password': password,
      'role': role,
      'permissions': permissions,
    });
    final msg = (response.data is Map) ? response.data['message'] as String? : null;
    if (response.statusCode != 201) return (success: false, error: msg ?? 'Tạo tài khoản thất bại');
    return (success: true, error: null);
  }

  Future<({bool success, String? error})> updatePermissions({
    required String employeeId,
    required String role,
    required List<String> permissions,
  }) async {
    final response = await _apiService.put('/store-users/$employeeId/permissions', body: {
      'role': role,
      'permissions': permissions,
    });
    final msg = (response.data is Map) ? response.data['message'] as String? : null;
    if (response.statusCode != 200) return (success: false, error: msg ?? 'Cập nhật quyền thất bại');
    return (success: true, error: null);
  }

  Future<({bool success, String? error})> resetStoreUserPassword({
    required String employeeId,
    required String newPassword,
  }) async {
    final response = await _apiService.put('/store-users/$employeeId/reset-password', body: {
      'newPassword': newPassword,
    });
    final msg = (response.data is Map) ? response.data['message'] as String? : null;
    if (response.statusCode != 200) return (success: false, error: msg ?? 'Đổi mật khẩu thất bại');
    return (success: true, error: null);
  }

  Future<({bool success, String? error})> removeStoreUser({required String employeeId}) async {
    final response = await _apiService.delete('/store-users/$employeeId');
    final msg = (response.data is Map) ? response.data['message'] as String? : null;
    if (response.statusCode != 200) return (success: false, error: msg ?? 'Xoá tài khoản thất bại');
    return (success: true, error: null);
  }
}
