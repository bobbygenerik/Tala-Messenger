import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  // Message reactions
  Future<void> addReaction(String messageId, String reaction, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final reactions = prefs.getStringList('reactions_$messageId') ?? [];
    final reactionData = '$userId:$reaction';
    if (!reactions.contains(reactionData)) {
      reactions.add(reactionData);
      await prefs.setStringList('reactions_$messageId', reactions);
      _messageController.add({'type': 'reaction', 'messageId': messageId, 'reaction': reaction});
    }
  }

  Future<List<String>> getReactions(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('reactions_$messageId') ?? [];
  }

  // Draft messages
  Future<void> saveDraft(String threadId, String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('draft_$threadId', text);
  }

  Future<String?> getDraft(String threadId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('draft_$threadId');
  }

  Future<void> clearDraft(String threadId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('draft_$threadId');
  }

  // Pinned messages
  Future<void> pinMessage(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final pinned = prefs.getStringList('pinned_messages') ?? [];
    if (!pinned.contains(messageId)) {
      pinned.add(messageId);
      await prefs.setStringList('pinned_messages', pinned);
    }
  }

  Future<void> unpinMessage(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final pinned = prefs.getStringList('pinned_messages') ?? [];
    pinned.remove(messageId);
    await prefs.setStringList('pinned_messages', pinned);
  }

  Future<List<String>> getPinnedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('pinned_messages') ?? [];
  }

  // Message search
  Future<List<Map<String, dynamic>>> searchMessages(String query) async {
    // Placeholder - would integrate with SMS service
    return [];
  }

  void dispose() {
    _messageController.close();
  }
}