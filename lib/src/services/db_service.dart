import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DBService {
  static Database? _database;

  static Future<void> initialize() async {
    if (_database != null) return;
    if (kIsWeb) return; // sqflite not available on web

    final docs = await getApplicationDocumentsDirectory();
    final path = join(docs.path, 'aqua_manager.db');

    _database = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pond (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            location TEXT,
            updatedAt TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE reading (
            id TEXT PRIMARY KEY,
            pondId TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            temperature REAL NOT NULL,
            pH REAL NOT NULL,
            oxygen REAL NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (pondId) REFERENCES pond(id) ON DELETE CASCADE
          );
        ''');

        // Generic offline cache table for any resource
        await db.execute('''
          CREATE TABLE cache (
            resource TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          );
        ''');

        // Offline action queue for mutations made while offline
        await db.execute('''
          CREATE TABLE offline_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            method TEXT NOT NULL,
            resource TEXT NOT NULL,
            itemId TEXT,
            body TEXT,
            createdAt TEXT NOT NULL
          );
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cache (
              resource TEXT PRIMARY KEY,
              data TEXT NOT NULL,
              updatedAt TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS offline_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              method TEXT NOT NULL,
              resource TEXT NOT NULL,
              itemId TEXT,
              body TEXT,
              createdAt TEXT NOT NULL
            );
          ''');
        }
      },
    );
  }

  static bool get isAvailable => _database != null;

  static Database get instance {
    if (_database == null) {
      throw StateError('DBService not initialized. Call initialize() first.');
    }
    return _database!;
  }

  // ── Cache operations ──

  /// Save a list of items for a resource to local cache
  static Future<void> cacheResource(String resource, List<Map<String, dynamic>> data) async {
    if (!isAvailable) return;
    await _database!.insert(
      'cache',
      {'resource': resource, 'data': jsonEncode(data), 'updatedAt': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached data for a resource
  static Future<List<Map<String, dynamic>>?> getCachedResource(String resource) async {
    if (!isAvailable) return null;
    final rows = await _database!.query('cache', where: 'resource = ?', whereArgs: [resource]);
    if (rows.isEmpty) return null;
    final data = jsonDecode(rows.first['data'] as String);
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ── Offline queue ──

  /// Enqueue an action to be synced later
  static Future<void> enqueueAction(String method, String resource, {String? itemId, Map<String, dynamic>? body}) async {
    if (!isAvailable) return;
    await _database!.insert('offline_queue', {
      'method': method,
      'resource': resource,
      'itemId': itemId,
      'body': body != null ? jsonEncode(body) : null,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Get all pending offline actions
  static Future<List<Map<String, dynamic>>> getPendingActions() async {
    if (!isAvailable) return [];
    return _database!.query('offline_queue', orderBy: 'id ASC');
  }

  /// Remove a synced action from the queue
  static Future<void> removeAction(int id) async {
    if (!isAvailable) return;
    await _database!.delete('offline_queue', where: 'id = ?', whereArgs: [id]);
  }

  /// Get pending action count
  static Future<int> pendingActionCount() async {
    if (!isAvailable) return 0;
    final result = await _database!.rawQuery('SELECT COUNT(*) as cnt FROM offline_queue');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
