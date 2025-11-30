import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/sms_service.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SmsService _smsService = SmsService();
  String _rcsStatus = "Checking...";

  @override
  void initState() {
    super.initState();
    _checkRcsStatus();
  }

  Future<void> _checkRcsStatus() async {
    final status = await _smsService.checkRcsAccess();
    if (mounted) {
      setState(() {
        _rcsStatus = status.contains("Success") ? "Connected" : "Disconnected";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Account Section
          _buildSectionHeader(context, 'Account'),
          _buildSectionContainer(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                subtitle: Text(settings.userName.isNotEmpty ? settings.userName : 'Set Name'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Phone Number'),
                subtitle: Text(settings.userPhone.isNotEmpty ? settings.userPhone : 'Unknown'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Appearance Section
          _buildSectionHeader(context, 'Appearance'),
          _buildSectionContainer(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Theme'),
                subtitle: Text(settings.themeMode.toString().split('.').last.toUpperCase()),
                trailing: DropdownButton<ThemeMode>(
                  value: settings.themeMode,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  ],
                  onChanged: (mode) {
                    if (mode != null) settings.setThemeMode(mode);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // RCS & Chat Section
          _buildSectionHeader(context, 'RCS & Chat'),
          _buildSectionContainer(
            context,
            children: [
              ListTile(
                leading: Icon(
                  Icons.check_circle,
                  color: _rcsStatus == "Connected" ? Colors.green : Colors.red,
                ),
                title: const Text('RCS Status'),
                subtitle: Text(_rcsStatus),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _checkRcsStatus,
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.power_settings_new),
                title: const Text('Enable RCS'),
                subtitle: const Text('Use experimental bypass'),
                value: settings.isRcsEnabled,
                onChanged: (value) => settings.setRcsEnabled(value),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.done_all),
                title: const Text('Read Receipts'),
                value: true, // Placeholder
                onChanged: (val) {}, 
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.more_horiz),
                title: const Text('Typing Indicators'),
                value: true, // Placeholder
                onChanged: (val) {},
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Debug Section
          _buildSectionHeader(context, 'Debug'),
          _buildSectionContainer(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.bug_report, color: Colors.red),
                title: const Text('Scan RCS APIs'),
                subtitle: const Text('Check for hidden methods'),
                onTap: () async {
                  final result = await Provider.of<SettingsProvider>(context, listen: false).smsService.debugRcsMethods();
                  _showDebugDialog(context, result);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Custom Actions Section
          _buildSectionHeader(context, 'Custom Actions'),
          _buildSectionContainer(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.call),
                title: const Text('Call App'),
                subtitle: Text(settings.callAppPackage.isNotEmpty ? settings.callAppPackage : 'Default (Phone)'),
                onTap: () => _showAppSelectionDialog(context, settings, true),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Video Call App'),
                subtitle: Text(settings.videoCallAppPackage.isNotEmpty ? settings.videoCallAppPackage : 'Default (Duo/Meet)'),
                onTap: () => _showAppSelectionDialog(context, settings, false),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Backup & Restore Section
          _buildSectionHeader(context, 'Backup & Restore'),
          _buildSectionContainer(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.upload),
                title: const Text('Export Chats'),
                subtitle: const Text('Save to JSON'),
                onTap: () async {
                  // TODO: Implement Export
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exporting... (Placeholder)')));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Import Chats'),
                subtitle: const Text('Restore from JSON'),
                onTap: () async {
                  // TODO: Implement Import
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importing... (Placeholder)')));
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // SMS Section
          _buildSectionHeader(context, 'SMS & MMS'),
          _buildSectionContainer(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.sms),
                title: const Text('Default SMS App'),
                subtitle: const Text('Tap to set as default'),
                onTap: () async {
                  await _smsService.requestDefaultSms();
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.notifications),
                title: const Text('Notifications'),
                value: settings.notificationsEnabled,
                onChanged: (val) => settings.setNotificationsEnabled(val),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.done_all),
                title: const Text('Delivery Reports'),
                value: settings.deliveryReportsEnabled,
                onChanged: (val) => settings.setDeliveryReportsEnabled(val),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.image),
                title: const Text('Auto-download MMS'),
                value: true, // Placeholder
                onChanged: (val) {},
              ),
            ],
          ),
          const SizedBox(height: 24),

          // iMessage Section
          _buildSectionHeader(context, 'iMessage (Bridge)'),
          _buildSectionContainer(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Bridge URL'),
                subtitle: Text(settings.iMessageBridgeUrl.isEmpty ? 'Not Configured' : settings.iMessageBridgeUrl),
                onTap: () => _showBridgeConfigDialog(context, settings),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.sync),
                title: const Text('Sync Contacts'),
                value: settings.syncContacts,
                onChanged: settings.iMessageBridgeUrl.isNotEmpty 
                    ? (val) => settings.setSyncContacts(val)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Privacy Section
          _buildSectionHeader(context, 'Privacy'),
          _buildSectionContainer(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Blocked Contacts'),
                subtitle: Text('${settings.blockedContacts.length} blocked'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showBlockedContactsDialog(context, settings),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.security),
                title: const Text('Spam Protection'),
                value: settings.spamProtectionEnabled,
                onChanged: (val) => settings.setSpamProtection(val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBridgeConfigDialog(BuildContext context, SettingsProvider settings) {
    final urlController = TextEditingController(text: settings.iMessageBridgeUrl);
    final passController = TextEditingController(text: settings.iMessagePassword);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252532),
        title: const Text('Configure Bridge', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Server URL',
                labelStyle: TextStyle(color: Colors.grey),
                hintText: 'https://...',
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              settings.setIMessageConfig(urlController.text, passController.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBlockedContactsDialog(BuildContext context, SettingsProvider settings) {
    final numberController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252532),
        title: const Text('Blocked Contacts', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: numberController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Add Number',
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.teal),
                    onPressed: () {
                      if (numberController.text.isNotEmpty) {
                        settings.addBlockedContact(numberController.text);
                        numberController.clear();
                        Navigator.pop(context); // Close to refresh (simple) or use StatefulBuilder
                        _showBlockedContactsDialog(context, settings); // Reopen
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (settings.blockedContacts.isEmpty)
                const Text('No blocked contacts', style: TextStyle(color: Colors.grey))
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: settings.blockedContacts.length,
                    itemBuilder: (context, index) {
                      final number = settings.blockedContacts[index];
                      return ListTile(
                        title: Text(number, style: const TextStyle(color: Colors.white)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            settings.removeBlockedContact(number);
                            Navigator.pop(context);
                            _showBlockedContactsDialog(context, settings);
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAppSelectionDialog(BuildContext context, SettingsProvider settings, bool isCall) {
    final controller = TextEditingController(
      text: isCall ? settings.callAppPackage : settings.videoCallAppPackage,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252532),
        title: Text(isCall ? 'Set Call App' : 'Set Video Call App', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the package name of the app you want to use (e.g., com.whatsapp, org.thoughtcrime.securesms). Leave empty for system default.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Package Name',
                labelStyle: TextStyle(color: Colors.grey),
                hintText: 'com.example.app',
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (isCall) {
                settings.setCallAppPackage(controller.text);
              } else {
                settings.setVideoCallAppPackage(controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDebugDialog(BuildContext context, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252532),
        title: const Text('RCS API Scan Result', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(content, style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 10)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSectionContainer(BuildContext context, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252532),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildColorOption(BuildContext context, SettingsProvider settings, Color color) {
    final isSelected = settings.seedColor.value == color.value;
    return GestureDetector(
      onTap: () => settings.setSeedColor(color),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
      ),
    );
  }
}
