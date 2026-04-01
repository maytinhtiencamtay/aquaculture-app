import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiResponse<T> {
  final int statusCode;
  final T? data;
  final String? message;

  ApiResponse({required this.statusCode, this.data, this.message});
}

class ApiService {
  static final String baseUrl = kIsWeb
      ? 'http://localhost:3000/api'
      : 'http://10.0.2.2:3000/api';

  static const _timeout = Duration(seconds: 30);

  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  String? _token;
  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        ..._defaultHeaders,
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  ApiResponse<dynamic> _parseResponse(http.Response resp) {
    dynamic data;
    try {
      data = resp.body.isEmpty ? null : jsonDecode(resp.body);
    } catch (_) {
      data = null;
    }
    return ApiResponse(statusCode: resp.statusCode, data: data, message: resp.reasonPhrase);
  }

  // ── Generic HTTP helpers ──

  Future<ApiResponse<dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final resp = await http.post(uri, headers: _headers, body: body == null ? null : jsonEncode(body)).timeout(_timeout);
      return _parseResponse(resp);
    } on TimeoutException {
      return ApiResponse(statusCode: 408, message: 'Hết thời gian kết nối');
    } catch (e) {
      return ApiResponse(statusCode: 0, message: e.toString());
    }
  }

  Future<ApiResponse<dynamic>> get(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final resp = await http.get(uri, headers: _headers).timeout(_timeout);
      return _parseResponse(resp);
    } on TimeoutException {
      return ApiResponse(statusCode: 408, message: 'Hết thời gian kết nối');
    } catch (e) {
      return ApiResponse(statusCode: 0, message: e.toString());
    }
  }

  Future<ApiResponse<dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final resp = await http.put(uri, headers: _headers, body: body == null ? null : jsonEncode(body)).timeout(_timeout);
      return _parseResponse(resp);
    } on TimeoutException {
      return ApiResponse(statusCode: 408, message: 'Hết thời gian kết nối');
    } catch (e) {
      return ApiResponse(statusCode: 0, message: e.toString());
    }
  }

  Future<ApiResponse<dynamic>> delete(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final resp = await http.delete(uri, headers: _headers).timeout(_timeout);
      return _parseResponse(resp);
    } on TimeoutException {
      return ApiResponse(statusCode: 408, message: 'Hết thời gian kết nối');
    } catch (e) {
      return ApiResponse(statusCode: 0, message: e.toString());
    }
  }

  // ── Resource helpers ──

  Future<List<Map<String, dynamic>>> fetchList(String resource) async {
    final response = await get('/$resource');
    if (response.statusCode != 200 || response.data == null) return [];
    return List<Map<String, dynamic>>.from(response.data as List);
  }

  Future<Map<String, dynamic>?> create(String resource, Map<String, dynamic> body) async {
    final response = await post('/$resource', body: body);
    if (response.statusCode == 201 && response.data != null) {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>?> update(String resource, String id, Map<String, dynamic> body) async {
    final response = await put('/$resource/$id', body: body);
    if (response.statusCode == 200 && response.data != null) {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }

  Future<bool> remove(String resource, String id) async {
    final response = await delete('/$resource/$id');
    return response.statusCode == 200;
  }

  // ── Export CSV ──
  Future<String?> exportCsv(String resource) async {
    final uri = Uri.parse('$baseUrl/export/$resource');
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode == 200) return resp.body;
    return null;
  }

  // ── Notifications ──
  Future<bool> markNotificationRead(String id) async {
    final resp = await put('/notifications/$id/read', body: {});
    return resp.statusCode == 200;
  }

  Future<bool> markAllNotificationsRead() async {
    final resp = await put('/notifications/read-all', body: {});
    return resp.statusCode == 200;
  }

  Future<bool> clearReadNotifications() async {
    final resp = await delete('/notifications/clear-read');
    return resp.statusCode == 200;
  }

  // ── Search ──
  Future<List<Map<String, dynamic>>> search(String query) async {
    final resp = await get('/search?q=${Uri.encodeComponent(query)}');
    if (resp.statusCode == 200 && resp.data is List) {
      return List<Map<String, dynamic>>.from(resp.data as List);
    }
    return [];
  }

  // ── Profile ──
  Future<Map<String, dynamic>?> updateProfile(Map<String, dynamic> body) async {
    final resp = await put('/profile', body: body);
    if (resp.statusCode == 200 && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    final resp = await put('/profile/password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    return resp.statusCode == 200;
  }

  // ── Harvest ──
  Future<Map<String, dynamic>?> createHarvest(Map<String, dynamic> body) async {
    final resp = await post('/harvest', body: body);
    if (resp.statusCode == 201 && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchHarvests() async {
    final resp = await get('/harvests');
    if (resp.statusCode == 200 && resp.data is List) {
      return List<Map<String, dynamic>>.from(resp.data as List);
    }
    return [];
  }

  // ── Profit analysis ──
  Future<List<Map<String, dynamic>>> fetchProfitAnalysis() async {
    final resp = await get('/analysis/profit');
    if (resp.statusCode == 200 && resp.data is List) {
      return List<Map<String, dynamic>>.from(resp.data as List);
    }
    return [];
  }

  // ── Supplier debts ──
  Future<List<Map<String, dynamic>>> fetchSupplierDebts() async {
    final resp = await get('/suppliers/debts');
    if (resp.statusCode == 200 && resp.data is List) {
      return List<Map<String, dynamic>>.from(resp.data as List);
    }
    return [];
  }

  // ── Feeding logs ──
  Future<List<Map<String, dynamic>>> fetchFeedingLogs() async {
    final resp = await get('/feedinglogs');
    if (resp.statusCode == 200 && resp.data is List) {
      return List<Map<String, dynamic>>.from(resp.data as List);
    }
    return [];
  }

  Future<Map<String, dynamic>?> createFeedingLog(Map<String, dynamic> body) async {
    final resp = await post('/feedinglogs', body: body);
    if (resp.statusCode == 201 && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }

  // ── Mortality logs ──
  Future<List<Map<String, dynamic>>> fetchMortalityLogs() async {
    final resp = await get('/mortalitylogs');
    if (resp.statusCode == 200 && resp.data is List) {
      return List<Map<String, dynamic>>.from(resp.data as List);
    }
    return [];
  }

  Future<Map<String, dynamic>?> createMortalityLog(Map<String, dynamic> body) async {
    final resp = await post('/mortalitylogs', body: body);
    if (resp.statusCode == 201 && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }
}
