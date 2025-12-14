
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/message_type_indicator.dart'; // For MessageType enum

class CapabilityService {
  static final CapabilityService _instance = CapabilityService._internal();
  factory CapabilityService() => _instance;
  CapabilityService._internal();

  // Cache to avoid constant lookups/randomization
  final Map<String, MessageType> _cache = {};

  Future<MessageType> getCapability(String phoneNumber, {bool isBridgeConfigured = false}) async {
    if (_cache.containsKey(phoneNumber)) {
      return _cache[phoneNumber]!;
    }

    // Check persistent storage first
    final prefs = await SharedPreferences.getInstance();
    final key = 'capability_$phoneNumber';
    if (prefs.containsKey(key)) {
      final index = prefs.getInt(key)!;
      final type = MessageType.values[index];
      _cache[phoneNumber] = type;
      return type;
    }

    // Determine capability
    MessageType type;
    
    if (isBridgeConfigured) {
      // If bridge is configured, we might detect iMessage.
      // For now, we simulate this with a hash.
      // In a real app, we'd query the bridge server.
      final hash = phoneNumber.hashCode;
      if (hash % 4 == 0) {
        type = MessageType.iMessage;
      } else if (hash % 4 == 1) {
        type = MessageType.rcs;
      } else {
        type = MessageType.sms;
      }
    } else {
      // Without bridge, only SMS or RCS
      // Simulate RCS detection (since we can't easily query UCE for every contact without a real backend)
      // We use hash to make it consistent per number.
      final hash = phoneNumber.hashCode;
      if (hash % 3 == 0) {
        type = MessageType.rcs;
      } else {
        type = MessageType.sms;
      }
    }

    // Cache and Persist
    _cache[phoneNumber] = type;
    await prefs.setInt(key, type.index);
    
    return type;
  }
  
  // Debug method to clear cache
  Future<void> clearCache() async {
    _cache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('capability_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
