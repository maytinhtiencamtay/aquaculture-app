import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider({AuthService? authService}) : _authService = authService ?? AuthService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  User? _user;
  User? get user => _user;

  bool get isAuthenticated => _user != null;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadFromCache() async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.getCachedUser();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _authService.signIn(email: email, password: password);
      if (result.user == null) {
        _errorMessage = result.error;
        return false;
      }
      _user = result.user;
      return true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String storeName,
    String? username,
    String? email,
    String? phone,
    String? address,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _authService.signUp(
        storeName: storeName,
        username: username,
        email: email,
        phone: phone,
        address: address,
        password: password,
      );
      if (result.user == null) {
        _errorMessage = result.error;
        return false;
      }
      _user = result.user;
      return true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> forgotPassword({required String email}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final error = await _authService.forgotPassword(email: email);
      if (error != null) {
        _errorMessage = error;
        return false;
      }
      return true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword({required String email, required String code, required String newPassword}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final error = await _authService.resetPassword(email: email, code: code, newPassword: newPassword);
      if (error != null) {
        _errorMessage = error;
        return false;
      }
      return true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    await _authService.signOut();
    _user = null;
    _isLoading = false;
    notifyListeners();
  }
}
