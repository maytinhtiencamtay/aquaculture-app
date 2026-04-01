import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import '../providers/data_provider.dart';

/// Notification service that periodically checks for alerts,
/// triggers backend notification generation, and sends web push notifications.
class NotificationService {
  static Timer? _timer;
  static Timer? _midnightTimer;
  static DataProvider? _dp;
  static bool _webNotificationsGranted = false;

  static Future<void> initialize() async {
    // Request web notification permission on supported browsers
    if (kIsWeb) {
      try {
        final permission = html.Notification.permission;
        if (permission == 'granted') {
          _webNotificationsGranted = true;
        } else if (permission != 'denied') {
          final result = await html.Notification.requestPermission();
          _webNotificationsGranted = (result == 'granted');
        }
      } catch (e) {
        debugPrint('Web Notification permission error: $e');
      }
    }
  }

  /// Start periodic notification checks (every 5 minutes)
  static void startPeriodicCheck(DataProvider dp) {
    _dp = dp;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _check());
    // Run initial check after a short delay
    Future.delayed(const Duration(seconds: 3), _check);
  }

  /// Stop periodic checks
  static void stop() {
    _timer?.cancel();
    _timer = null;
    _midnightTimer?.cancel();
    _midnightTimer = null;
    _dp = null;
  }

  static Future<void> _check() async {
    try {
      final prevCount = _dp?.unreadNotifications ?? 0;
      await _dp?.checkNotifications();
      final newCount = _dp?.unreadNotifications ?? 0;
      // Show web notification if there are new unread notifications
      if (newCount > prevCount) {
        showReminder(
          title: 'AQUA Manager',
          body: 'Bạn có ${newCount - prevCount} thông báo mới',
        );
      }
    } catch (e) {
      debugPrint('NotificationService check error: $e');
    }
  }

  /// Also handles midnight refresh for Task.isOverdue recalculation
  static void startMidnightRefresh(DataProvider dp) {
    _dp = dp;
    _midnightTimer?.cancel();
    _scheduleMidnightRefresh();
  }

  static void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final duration = midnight.difference(now);
    _midnightTimer = Timer(duration, () {
      _dp?.refreshOverdueState();
      _dp?.checkNotifications();
      _scheduleMidnightRefresh(); // Schedule next midnight
    });
  }

  /// Show a notification — uses browser Notification API on web, debugPrint fallback
  static Future<void> showReminder({
    required String title,
    required String body,
    int id = 0,
  }) async {
    debugPrint('Notification: [$title] $body');
    if (kIsWeb && _webNotificationsGranted) {
      try {
        html.Notification(title, body: body, icon: 'icons/Icon-192.png');
      } catch (e) {
        debugPrint('Web notification error: $e');
      }
    }
  }
}
