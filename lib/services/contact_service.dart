import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactService {
  static final ContactService _instance = ContactService._internal();
  factory ContactService() => _instance;
  ContactService._internal();

  List<Contact> _contacts = [];
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    if (await FlutterContacts.requestPermission()) {
      _contacts = await FlutterContacts.getContacts(withProperties: true);
      _isInitialized = true;
    }
  }

  String? getNameForNumber(String number) {
    if (!_isInitialized) return null;
    
    // Normalize input number (remove non-digits)
    final cleanInput = number.replaceAll(RegExp(r'\D'), '');
    if (cleanInput.isEmpty) return null;

    for (final contact in _contacts) {
      for (final phone in contact.phones) {
        final cleanPhone = phone.number.replaceAll(RegExp(r'\D'), '');
        // Simple matching: check if one ends with the other (to handle country codes)
        if (cleanPhone.endsWith(cleanInput) || cleanInput.endsWith(cleanPhone)) {
          return contact.displayName;
        }
      }
    }
    return null;
  }

  Future<void> refreshContacts() async {
    _isInitialized = false;
    await init();
  }
}
