import 'package:flutter/services.dart';

class SmsService {
  static const platform = MethodChannel('com.example.holy_grail_messenger/sms');

  Future<void> requestDefaultSms() async {
    try {
      await platform.invokeMethod('requestDefaultSms');
    } on PlatformException catch (e) {
      print("Failed to request default SMS: '${e.message}'.");
    }
  }

  Future<bool> isDefaultSms() async {
    try {
      final bool result = await platform.invokeMethod('isDefaultSms');
      return result;
    } on PlatformException catch (e) {
      print("Failed to check default SMS: '${e.message}'.");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getConversations');
      return result.cast<Map<dynamic, dynamic>>().map((e) => e.cast<String, dynamic>()).toList();
    } on PlatformException catch (e) {
      print("Failed to get conversations: '${e.message}'.");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String threadId) async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getMessages', {'threadId': threadId});
      return result.cast<Map<dynamic, dynamic>>().map((e) => e.cast<String, dynamic>()).toList();
    } on PlatformException catch (e) {
      print("Failed to get messages: '${e.message}'.");
      return [];
    }
  }

  Future<bool> checkRcsAccess() async {
    try {
      final bool result = await platform.invokeMethod('checkRcsAccess');
      return result;
    } on PlatformException catch (e) {
      print("Failed to check RCS access: '${e.message}'.");
      return false;
    }
  }
}
