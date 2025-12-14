import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sms_service.dart';
import '../services/contact_service.dart';
import '../services/haptic_service.dart';

class SettingsProvider with ChangeNotifier {
  final SmsService _smsService = SmsService();
  final ContactService _contactService = ContactService();
  final HapticService _hapticService = HapticService();
  
  SmsService get smsService => _smsService;
  ContactService get contactService => _contactService;
  HapticService get hapticService => _hapticService;

  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = Colors.teal;
  bool _isRcsEnabled = true;
  
  // iMessage Config
  String _iMessageBridgeUrl = '';
  String _iMessagePassword = '';
  bool _syncContacts = false;

  // Privacy
  List<String> _blockedContacts = [];
  bool _spamProtectionEnabled = false;

  // Profile
  String _userName = '';
  String _userPhone = '';
  String _userProfileImagePath = '';

  // Archive
  List<String> _archivedThreads = [];

  // Messaging Settings
  bool _notificationsEnabled = true;
  bool _deliveryReportsEnabled = false;
  bool _hapticsEnabled = true;

  // Custom Actions
  String _callAppPackage = '';
  String _videoCallAppPackage = '';

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  bool get isRcsEnabled => _isRcsEnabled;
  
  String get iMessageBridgeUrl => _iMessageBridgeUrl;
  String get iMessagePassword => _iMessagePassword;
  bool get syncContacts => _syncContacts;

  List<String> get blockedContacts => _blockedContacts;
  bool get spamProtectionEnabled => _spamProtectionEnabled;

  String get userName => _userName;
  String get userPhone => _userPhone;
  String get userProfileImagePath => _userProfileImagePath;

  List<String> get archivedThreads => _archivedThreads;
  
  bool get notificationsEnabled => _notificationsEnabled;
  bool get deliveryReportsEnabled => _deliveryReportsEnabled;
  bool get hapticsEnabled => _hapticsEnabled;

  String get callAppPackage => _callAppPackage;
  String get videoCallAppPackage => _videoCallAppPackage;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? 0;
    final colorValue = prefs.getInt('seedColor') ?? ((Colors.teal.a * 255).round() << 24) | ((Colors.teal.r * 255).round() << 16) | ((Colors.teal.g * 255).round() << 8) | (Colors.teal.b * 255).round();
    _isRcsEnabled = prefs.getBool('isRcsEnabled') ?? true;
    
    // Init contacts
    _contactService.init().then((_) => notifyListeners());

    _iMessageBridgeUrl = prefs.getString('iMessageBridgeUrl') ?? '';
    _iMessagePassword = prefs.getString('iMessagePassword') ?? '';
    _syncContacts = prefs.getBool('syncContacts') ?? false;

    _blockedContacts = prefs.getStringList('blockedContacts') ?? [];
    _spamProtectionEnabled = prefs.getBool('spamProtectionEnabled') ?? false;

    _userName = prefs.getString('userName') ?? '';
    _userPhone = prefs.getString('userPhone') ?? '';
    _userProfileImagePath = prefs.getString('userProfileImagePath') ?? '';

    _archivedThreads = prefs.getStringList('archivedThreads') ?? [];
    
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    _deliveryReportsEnabled = prefs.getBool('deliveryReportsEnabled') ?? false;
    _hapticsEnabled = prefs.getBool('hapticsEnabled') ?? true;
    _hapticService.setEnabled(_hapticsEnabled);

    _callAppPackage = prefs.getString('callAppPackage') ?? '';
    _videoCallAppPackage = prefs.getString('videoCallAppPackage') ?? '';

    _themeMode = ThemeMode.values[themeIndex];
    _seedColor = Color(colorValue);
    notifyListeners();
  }

  // ... existing setters ...

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', enabled);
  }

  Future<void> setDeliveryReportsEnabled(bool enabled) async {
    _deliveryReportsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('deliveryReportsEnabled', enabled);
  }

  // ... existing setters ...

  Future<void> setProfileInfo(String name, String phone, String imagePath) async {
    _userName = name;
    _userPhone = phone;
    _userProfileImagePath = imagePath;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    await prefs.setString('userPhone', phone);
    await prefs.setString('userProfileImagePath', imagePath);
  }

  Future<void> archiveThread(String threadId) async {
    if (!_archivedThreads.contains(threadId)) {
      _archivedThreads.add(threadId);
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('archivedThreads', _archivedThreads);
    }
  }

  Future<void> unarchiveThread(String threadId) async {
    _archivedThreads.remove(threadId);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('archivedThreads', _archivedThreads);
  }

  Future<void> deleteThread(String threadId) async {
    // Remove from archive if present
    if (_archivedThreads.contains(threadId)) {
      _archivedThreads.remove(threadId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('archivedThreads', _archivedThreads);
    }
    // Call service to delete
    await smsService.deleteConversation(threadId);
    notifyListeners();
  }

  // ... existing setters ...

  Future<void> setIMessageConfig(String url, String password) async {
    _iMessageBridgeUrl = url;
    _iMessagePassword = password;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('iMessageBridgeUrl', url);
    await prefs.setString('iMessagePassword', password);
  }

  Future<void> setSyncContacts(bool enabled) async {
    _syncContacts = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('syncContacts', enabled);
  }

  Future<void> addBlockedContact(String number) async {
    if (!_blockedContacts.contains(number)) {
      _blockedContacts.add(number);
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('blockedContacts', _blockedContacts);
    }
  }

  Future<void> removeBlockedContact(String number) async {
    _blockedContacts.remove(number);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blockedContacts', _blockedContacts);
  }

  Future<void> setSpamProtection(bool enabled) async {
    _spamProtectionEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('spamProtectionEnabled', enabled);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seedColor', ((color.a * 255).round() << 24) | ((color.r * 255).round() << 16) | ((color.g * 255).round() << 8) | (color.b * 255).round());
  }

  Future<void> setRcsEnabled(bool enabled) async {
    _isRcsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isRcsEnabled', enabled);
  }

  Future<void> setCallAppPackage(String packageName) async {
    _callAppPackage = packageName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('callAppPackage', packageName);
  }

  Future<void> setVideoCallAppPackage(String packageName) async {
    _videoCallAppPackage = packageName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('videoCallAppPackage', packageName);
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    _hapticsEnabled = enabled;
    _hapticService.setEnabled(enabled);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hapticsEnabled', enabled);
  }
}
