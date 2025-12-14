import 'package:flutter/material.dart';
import '../services/unified_messaging_service.dart';

/// Main screen for unified messaging overlay
/// This replaces the traditional SMS interface with unified messaging
class UnifiedOverlayScreen extends StatefulWidget {
  const UnifiedOverlayScreen({Key? key}) : super(key: key);

  @override
  State<UnifiedOverlayScreen> createState() => _UnifiedOverlayScreenState();
}

class _UnifiedOverlayScreenState extends State<UnifiedOverlayScreen> {
  final UnifiedMessagingService _messagingService = UnifiedMessagingService();
  List<UnifiedThread> _threads = [];
  bool _isLoading = true;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndInitialize();
  }

  Future<void> _checkPermissionsAndInitialize() async {
    // Check if permissions are granted
    // In a real implementation, you'd check actual permission status
    setState(() {
      _permissionsGranted = false; // Start with false to show setup
    });

    if (_permissionsGranted) {
      await _initializeMessaging();
    }
  }

  Future<void> _initializeMessaging() async {
    await _messagingService.initialize();
    
    _messagingService.inboxStream.listen((threads) {
      if (mounted) {
        setState(() {
          _threads = threads;
          _isLoading = false;
        });
      }
    });

    final threads = await _messagingService.getUnifiedInbox();
    if (mounted) {
      setState(() {
        _threads = threads;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _messagingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionsGranted) {
      return _buildPermissionSetup();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unified Messages'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshInbox,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _threads.isEmpty
              ? _buildEmptyState()
              : _buildThreadsList(),
    );
  }

  Widget _buildPermissionSetup() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Unified Messaging'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security,
              size: 80,
              color: Colors.blue[600],
            ),
            const SizedBox(height: 24),
            const Text(
              'Enable Unified Messaging',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'To use unified messaging, this app needs to monitor notifications from Google Messages and Messenger. Your messages stay private and are only cached locally.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            _buildPermissionCard(
              'Notification Access',
              'Monitor messages from Google Messages and Messenger',
              Icons.notifications,
              () => _messagingService.requestNotificationAccess(),
            ),
            const SizedBox(height: 16),
            _buildPermissionCard(
              'Accessibility Service',
              'Detect typing indicators and read receipts',
              Icons.accessibility,
              () => _messagingService.requestAccessibilityAccess(),
            ),
            const SizedBox(height: 16),
            _buildPermissionCard(
              'Overlay Permission',
              'Show floating chat bubbles',
              Icons.bubble_chart,
              () => _messagingService.requestOverlayPermission(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _permissionsGranted = true;
                });
                _initializeMessaging();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Continue to Unified Inbox'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard(String title, String description, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blue[600]),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Messages from Google Messages and Messenger will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildThreadsList() {
    return ListView.builder(
      itemCount: _threads.length,
      itemBuilder: (context, index) {
        final thread = _threads[index];
        return _buildThreadTile(thread);
      },
    );
  }

  Widget _buildThreadTile(UnifiedThread thread) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: _buildPlatformAvatar(thread),
        title: Row(
          children: [
            Expanded(
              child: Text(
                thread.sender,
                style: TextStyle(
                  fontWeight: thread.unreadCount > 0 
                      ? FontWeight.bold 
                      : FontWeight.normal,
                ),
              ),
            ),
            if (thread.isTyping)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'typing...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              thread.lastMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              thread.platformDisplayName,
              style: TextStyle(
                fontSize: 12,
                color: Color(thread.platformColor),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: thread.unreadCount > 0
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  thread.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () => _openInNativeApp(thread),
        onLongPress: () => _showBubble(thread),
      ),
    );
  }

  Widget _buildPlatformAvatar(UnifiedThread thread) {
    IconData icon;
    switch (thread.platform) {
      case 'google_messages':
        icon = Icons.message;
        break;
      case 'messenger':
        icon = Icons.facebook;
        break;
      case 'whatsapp':
        icon = Icons.chat;
        break;
      case 'telegram':
        icon = Icons.send;
        break;
      case 'signal':
        icon = Icons.security;
        break;
      case 'open_bubbles':
        icon = Icons.bubble_chart;
        break;
      default:
        icon = Icons.chat;
    }

    return CircleAvatar(
      backgroundColor: Color(thread.platformColor),
      child: Icon(
        icon,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Future<void> _refreshInbox() async {
    final threads = await _messagingService.getUnifiedInbox();
    if (mounted) {
      setState(() {
        _threads = threads;
      });
    }
  }

  void _openInNativeApp(UnifiedThread thread) {
    // Open the conversation in the native app
    _messagingService.sendUnifiedMessage(
      platform: thread.platform,
      message: '', // Empty message just opens the app
      recipient: thread.sender,
    );
  }

  void _showBubble(UnifiedThread thread) {
    _messagingService.showBubble(
      sender: thread.sender,
      message: thread.lastMessage,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bubble shown! You can now minimize the app.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}