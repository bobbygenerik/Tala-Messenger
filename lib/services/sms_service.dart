import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class SmsService {
  static const platform = MethodChannel('com.example.holy_grail_messenger/sms');

  Future<void> requestDefaultSms() async {
    try {
      await platform.invokeMethod('requestDefaultSms');
    } on PlatformException catch (e) {
      debugPrint("Failed to request default SMS: '${e.message}'.");
    }
  }

  Future<bool> isDefaultSms() async {
    try {
      final bool result = await platform.invokeMethod('isDefaultSms');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to check default SMS: '${e.message}'.");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getConversations');
      return result.cast<Map<dynamic, dynamic>>().map((e) => e.cast<String, dynamic>()).toList();
    } on PlatformException catch (e) {
      debugPrint("Failed to get conversations: '${e.message}'.");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String threadId) async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getMessages', {'threadId': threadId});
      return result.cast<Map<dynamic, dynamic>>().map((e) => e.cast<String, dynamic>()).toList();
    } on PlatformException catch (e) {
      debugPrint("Failed to get messages: '${e.message}'.");
      return [];
    }
  }

  Future<String> checkRcsAccess() async {
    try {
      final result = await platform.invokeMethod('checkRcsAccess');
      return result.toString();
    } on PlatformException catch (e) {
      debugPrint("Failed to check RCS access: '${e.message}'.");
      return "Error: ${e.message}";
    }
  }

  Future<void> sendSms(String address, String body) async {
    try {
      await platform.invokeMethod('sendSms', {'address': address, 'body': body});
    } on PlatformException catch (e) {
      debugPrint("Failed to send SMS: '${e.message}'.");
    }
  }

  Future<void> deleteConversation(String threadId) async {
    try {
      await platform.invokeMethod('deleteConversation', {'threadId': threadId});
    } on PlatformException catch (e) {
      debugPrint("Failed to delete conversation: '${e.message}'.");
    }
  }

  Future<void> markAsRead(String threadId) async {
    try {
      await platform.invokeMethod('markAsRead', {'threadId': threadId});
    } on PlatformException catch (e) {
      debugPrint("Failed to mark as read: '${e.message}'.");
    }
  }
  Future<void> launchApp(String packageName) async {
    try {
      await platform.invokeMethod('launchApp', {'packageName': packageName});
    } on PlatformException catch (e) {
      debugPrint("Failed to launch app: '${e.message}'.");
    }
  }

  Future<void> launchVideoCall(String packageName, String contact) async {
    try {
      // Try platform method first
      await platform.invokeMethod('launchVideoCall', {
        'packageName': packageName,
        'contact': contact,
      });
    } on PlatformException catch (e) {
      debugPrint("Platform method failed: '${e.message}', trying URL launcher");
      // Fallback to URL launcher for common apps
      String? url;
      switch (packageName) {
        case 'com.google.android.apps.meetings':
          url = 'https://meet.google.com/new';
          break;
        case 'com.whatsapp':
          url = 'https://wa.me/$contact';
          break;
        case 'us.zoom.videomeetings':
          url = 'https://zoom.us/start/videomeeting';
          break;
        default:
          url = 'tel:$contact';
      }
      
      if (url != null && await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        debugPrint("Cannot launch video call for $packageName");
      }
    }
  }

  Future<void> exportChats() async {
    try {
      final conversations = await getConversations();
      final List<Map<String, dynamic>> fullBackup = [];

      for (final conv in conversations) {
        final threadId = conv['threadId'] as String;
        final messages = await getMessages(threadId);
        fullBackup.add({
          'conversation': conv,
          'messages': messages,
        });
      }

      final jsonString = jsonEncode(fullBackup);
      
      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);
      
      debugPrint("Backup saved to ${file.path}");
      // In a real app, we might share this file or let user pick location.
    } catch (e) {
      debugPrint("Failed to export chats: $e");
    }
  }

  Future<void> importChats() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        File file = File(result.files.single.path!);
        String jsonString = await file.readAsString();
        List<dynamic> backup = jsonDecode(jsonString);
        
        debugPrint("Imported ${backup.length} conversations.");
        // Here we would insert into DB. Since we are using system SMS, we can't easily write back.
        // We'll just log it for now.
      }
    } catch (e) {
      debugPrint("Failed to import chats: $e");
    }
  }

  Future<String> debugRcsMethods() async {
    try {
      final result = await platform.invokeMethod('debugRcsMethods');
      return result.toString();
    } on PlatformException catch (e) {
      return "Error: ${e.message}";
    }
  }

  Future<void> saveBackup(Map<String, dynamic> data, String fileName) async {
    try {
      final directory = await getExternalStorageDirectory();
      final downloadsDir = Directory('${directory?.parent.parent.parent.parent.path}/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      throw Exception('Failed to save backup: $e');
    }
  }

  Future<Map<String, dynamic>?> loadBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String jsonString = await file.readAsString();
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to load backup: $e');
    }
  }
}
