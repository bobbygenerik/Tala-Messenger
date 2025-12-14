import 'package:flutter/material.dart';
import '../services/unified_messaging_service.dart';

/// Widget displaying the unified inbox with messages from all platforms
class UnifiedInbox extends StatefulWidget {
  const UnifiedInbox({Key? key}) : super(key: key);

  @override
  State<UnifiedInbox> createState() => _UnifiedInboxState();
}

class _UnifiedInboxState extends State<UnifiedInbox> {
  final UnifiedMessagingService _messagingService = UnifiedMessagingService();
  List<UnifiedThread> _threads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeMessaging();
  }

  Future<void> _initializeMessaging() async {
    await _messagingService.initialize();
    
    // Listen to inbox updates
    _messagingService.inboxStream.listen((threads) {
      if (mounted) {
        setState(() {
          _threads = threads;
          _isLoading = false;
        });
      }
    });

    // Load initial data
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unified Inbox'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showPermissionsDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _threads.isEmpty
              ? _buildEmptyState()
              : _buildThreadsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewMessageDialog,
        child: const Icon(Icons.add),
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
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enable permissions to start receiving messages',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _showPermissionsDialog,
            child: const Text('Setup Permissions'),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadsList() {
    return RefreshIndicator(
      onRefresh: _refreshInbox,
      child: ListView.builder(
        itemCount: _threads.length,
        itemBuilder: (context, index) {
          final thread = _threads[index];
          return _buildThreadTile(thread);
        },
      ),
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
              style: TextStyle(
                color: thread.unreadCount > 0 
                    ? Colors.black87 
                    : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  thread.platformDisplayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(thread.platformColor),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(thread.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
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
        onTap: () => _openConversation(thread),
        onLongPress: () => _showThreadOptions(thread),
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
      case 'sms':
        icon = Icons.sms;
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

  String _formatTimestamp(int timestamp) {
    final now = DateTime.now();
    final messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(messageTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  Future<void> _refreshInbox() async {
    final threads = await _messagingService.getUnifiedInbox();
    if (mounted) {
      setState(() {
        _threads = threads;
      });
    }
  }

  void _openConversation(UnifiedThread thread) {
    // Navigate to conversation view
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedConversationScreen(thread: thread),
      ),
    );
  }

  void _showThreadOptions(UnifiedThread thread) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.bubble_chart),
            title: const Text('Show as Bubble'),
            onTap: () {
              Navigator.pop(context);
              _messagingService.showBubble(
                sender: thread.sender,
                message: thread.lastMessage,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.mark_email_read),
            title: const Text('Mark as Read'),
            onTap: () {
              Navigator.pop(context);
              // Implement mark as read
            },
          ),
          ListTile(
            leading: const Icon(Icons.reply),
            title: const Text('Quick Reply'),
            onTap: () {
              Navigator.pop(context);
              _showQuickReply(thread);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy Message'),
            onTap: () {
              Navigator.pop(context);
              _copyMessage(thread.lastMessage);
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text('Open in ${thread.platformDisplayName}'),
            onTap: () {
              Navigator.pop(context);
              _openApp(_getPackageName(thread.platform));
            },
          ),
        ],
      ),
    );
  }

  void _showPermissionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setup Permissions'),
        content: const Text(
          'To use unified messaging, please enable:\n\n'
          '• Notification Access\n'
          '• Accessibility Service\n'
          '• Overlay Permission\n\n'
          'These allow the app to intercept messages and show bubbles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _messagingService.requestNotificationAccess();
              await _messagingService.requestAccessibilityAccess();
              await _messagingService.requestOverlayPermission();
            },
            child: const Text('Setup'),
          ),
        ],
      ),
    );
  }

  void _showNewMessageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Message'),
        content: const Text(
          'Choose how to send your message:\n\n'
          '• SMS: Send directly through Tala\n'
          '• Other platforms: Opens the app for you\n\n'
          'All replies will appear here in your unified inbox.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to SMS compose
              Navigator.pushNamed(context, '/compose');
            },
            child: const Text('SMS'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showPlatformSelector();
            },
            child: const Text('Other Apps'),
          ),
        ],
      ),
    );
  }

  void _showPlatformSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Open messaging app',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.message, color: Colors.blue),
            title: const Text('Messages'),
            onTap: () => _openApp('com.google.android.apps.messaging'),
          ),
          ListTile(
            leading: const Icon(Icons.facebook, color: Colors.blue),
            title: const Text('Messenger'),
            onTap: () => _openApp('com.facebook.orca'),
          ),
          ListTile(
            leading: const Icon(Icons.chat, color: Colors.green),
            title: const Text('WhatsApp'),
            onTap: () => _openApp('com.whatsapp'),
          ),
          ListTile(
            leading: const Icon(Icons.send, color: Colors.blue),
            title: const Text('Telegram'),
            onTap: () => _openApp('org.telegram.messenger'),
          ),
        ],
      ),
    );
  }

  void _openApp(String packageName) {
    Navigator.pop(context);
    _messagingService.openApp(packageName);
  }
}

  void _showQuickReply(UnifiedThread thread) {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reply to ${thread.sender}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Platform: ${thread.platformDisplayName}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            if (thread.platform == 'sms')
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Type your reply...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'This will open ${thread.platformDisplayName} to reply',
                  style: const TextStyle(color: Colors.orange),
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
              Navigator.pop(context);
              if (thread.platform == 'sms') {
                _messagingService.sendSMS(thread.sender, controller.text);
              } else {
                _openApp(_getPackageName(thread.platform));
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _copyMessage(String message) {
    // Copy to clipboard functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard')),
    );
  }

  String _getPackageName(String platform) {
    switch (platform) {
      case 'google_messages':
        return 'com.google.android.apps.messaging';
      case 'messenger':
        return 'com.facebook.orca';
      case 'whatsapp':
        return 'com.whatsapp';
      case 'telegram':
        return 'org.telegram.messenger';
      case 'signal':
        return 'org.thoughtcrime.securesms';
      default:
        return '';
    }
  }
}

/// Placeholder for conversation screen
class UnifiedConversationScreen extends StatelessWidget {
  final UnifiedThread thread;

  const UnifiedConversationScreen({Key? key, required this.thread}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(thread.sender),
        backgroundColor: Color(thread.platformColor),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openInNativeApp(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    thread.platform == 'sms' 
                        ? 'You can send and receive SMS messages directly here'
                        : 'Messages from ${thread.platformDisplayName} appear here. Tap the app icon to reply.',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('Message history will appear here'),
            ),
          ),
          if (thread.platform == 'sms')
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openInNativeApp() {
    // Open the native app for this platform
  }
}