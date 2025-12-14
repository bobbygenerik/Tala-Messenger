import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
  }

  Future<void> showMessageNotification({
    required String sender,
    required String message,
    required String threadId,
  }) async {
    await init();
    
    // Simple debug notification - in production this would use platform channels
    debugPrint('Notification: $sender - $message');
  }

  Future<void> cancelNotification(String threadId) async {
    debugPrint('Cancelled notification for thread: $threadId');
  }

  Future<void> setNotificationSound(String soundPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_sound', soundPath);
  }

  Future<String?> getNotificationSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notification_sound');
  }
}