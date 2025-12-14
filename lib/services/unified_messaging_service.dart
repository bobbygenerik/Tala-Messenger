import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for interfacing with the unified messaging system
/// Handles communication between Flutter UI and native Android services
class UnifiedMessagingService {
  static const MethodChannel _channel = MethodChannel('com.example.holy_grail_messenger/sms');
  
  // Stream controllers for real-time updates
  final StreamController<List<UnifiedThread>> _inboxController = StreamController.broadcast();
  final StreamController<UnifiedMessage> _newMessageController = StreamController.broadcast();
  final StreamController<TypingStatus> _typingController = StreamController.broadcast();
  
  // Streams for UI to listen to
  Stream<List<UnifiedThread>> get inboxStream => _inboxController.stream;
  Stream<UnifiedMessage> get newMessageStream => _newMessageController.stream;
  Stream<TypingStatus> get typingStream => _typingController.stream;

  /// Request notification listener permission
  Future<void> requestNotificationAccess() async {
    try {
      await _channel.invokeMethod('requestNotificationAccess');
    } catch (e) {
      debugPrint('Error requesting notification access: $e');
    }
  }

  /// Request accessibility service permission
  Future<void> requestAccessibilityAccess() async {
    try {
      await _channel.invokeMethod('requestAccessibilityAccess');
    } catch (e) {
      debugPrint('Error requesting accessibility access: $e');
    }
  }

  /// Request overlay permission for bubbles
  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('Error requesting overlay permission: $e');
    }
  }

  /// Get unified inbox with messages from all platforms
  Future<List<UnifiedThread>> getUnifiedInbox() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getUnifiedInbox');
      return result.map((item) => UnifiedThread.fromMap(item)).toList();
    } catch (e) {
      debugPrint('Error getting unified inbox: $e');
      return [];
    }
  }

  /// Send message through unified system
  Future<void> sendUnifiedMessage({
    required String platform,
    required String message,
    required String recipient,
  }) async {
    try {
      await _channel.invokeMethod('sendUnifiedMessage', {
        'platform': platform,
        'message': message,
        'recipient': recipient,
      });
    } catch (e) {
      debugPrint('Error sending unified message: $e');
    }
  }

  /// Show bubble notification
  Future<void> showBubble({
    required String sender,
    required String message,
  }) async {
    try {
      await _channel.invokeMethod('showBubble', {
        'sender': sender,
        'message': message,
      });
    } catch (e) {
      debugPrint('Error showing bubble: $e');
    }
  }

  /// Initialize unified messaging system
  Future<void> initialize() async {
    // Start listening for updates from native services
    // In a real implementation, you'd set up broadcast receivers
    // or use EventChannel for real-time updates
    
    // Simulate periodic inbox updates
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      final inbox = await getUnifiedInbox();
      _inboxController.add(inbox);
    });
  }

  /// Dispose resources
  void dispose() {
    _inboxController.close();
    _newMessageController.close();
    _typingController.close();
  }
}

/// Represents a unified conversation thread
class UnifiedThread {
  final String threadKey;
  final String platform;
  final String sender;
  final String lastMessage;
  final int timestamp;
  final int unreadCount;
  final bool isTyping;

  UnifiedThread({
    required this.threadKey,
    required this.platform,
    required this.sender,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.isTyping,
  });

  factory UnifiedThread.fromMap(Map<dynamic, dynamic> map) {
    return UnifiedThread(
      threadKey: map['threadKey'] ?? '',
      platform: map['platform'] ?? '',
      sender: map['sender'] ?? '',
      lastMessage: map['lastMessage'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      unreadCount: map['unreadCount'] ?? 0,
      isTyping: map['isTyping'] ?? false,
    );
  }

  /// Get platform display name
  String get platformDisplayName {
    switch (platform) {
      case 'google_messages':
        return 'Messages';
      case 'messenger':
        return 'Messenger';
      case 'whatsapp':
        return 'WhatsApp';
      case 'telegram':
        return 'Telegram';
      case 'signal':
        return 'Signal';
      case 'open_bubbles':
        return 'Open Bubbles';
      case 'sms':
        return 'SMS';
      default:
        return platform;
    }
  }

  /// Get platform color
  int get platformColor {
    switch (platform) {
      case 'google_messages':
        return 0xFF4285F4; // Google Blue
      case 'messenger':
        return 0xFF0084FF; // Messenger Blue
      case 'whatsapp':
        return 0xFF25D366; // WhatsApp Green
      case 'telegram':
        return 0xFF0088CC; // Telegram Blue
      case 'signal':
        return 0xFF3A76F0; // Signal Blue
      case 'open_bubbles':
        return 0xFFFF6B35; // Orange
      case 'sms':
        return 0xFF34A853; // Green
      default:
        return 0xFF9E9E9E; // Gray
    }
  }
}

/// Represents a unified message
class UnifiedMessage {
  final String id;
  final String platform;
  final String sender;
  final String message;
  final String conversationId;
  final int timestamp;
  final bool isRead;
  final List<MessageReaction> reactions;

  UnifiedMessage({
    required this.id,
    required this.platform,
    required this.sender,
    required this.message,
    required this.conversationId,
    required this.timestamp,
    required this.isRead,
    required this.reactions,
  });

  factory UnifiedMessage.fromMap(Map<dynamic, dynamic> map) {
    final List<dynamic> reactionsData = map['reactions'] ?? [];
    final reactions = reactionsData
        .map((r) => MessageReaction.fromMap(r))
        .toList();

    return UnifiedMessage(
      id: map['id'] ?? '',
      platform: map['platform'] ?? '',
      sender: map['sender'] ?? '',
      message: map['message'] ?? '',
      conversationId: map['conversationId'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      isRead: map['isRead'] ?? false,
      reactions: reactions,
    );
  }
}

/// Represents a message reaction
class MessageReaction {
  final String emoji;
  final String sender;
  final int timestamp;

  MessageReaction({
    required this.emoji,
    required this.sender,
    required this.timestamp,
  });

  factory MessageReaction.fromMap(Map<dynamic, dynamic> map) {
    return MessageReaction(
      emoji: map['emoji'] ?? '',
      sender: map['sender'] ?? '',
      timestamp: map['timestamp'] ?? 0,
    );
  }
}

/// Represents typing status
class TypingStatus {
  final String threadKey;
  final String sender;
  final bool isTyping;
  final String platform;

  TypingStatus({
    required this.threadKey,
    required this.sender,
    required this.isTyping,
    required this.platform,
  });

  factory TypingStatus.fromMap(Map<dynamic, dynamic> map) {
    return TypingStatus(
      threadKey: map['threadKey'] ?? '',
      sender: map['sender'] ?? '',
      isTyping: map['isTyping'] ?? false,
      platform: map['platform'] ?? '',
    );
  }
}