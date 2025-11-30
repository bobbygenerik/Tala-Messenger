import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/sms_service.dart';
import '../services/capability_service.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';
import '../providers/settings_provider.dart';
import 'message_type_indicator.dart';

class Sidebar extends StatefulWidget {
  final Function(String?, String)? onConversationSelected;

  const Sidebar({super.key, this.onConversationSelected});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final SmsService _smsService = SmsService();
  late Future<List<Map<String, dynamic>>> _conversationsFuture;
  bool _showArchived = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _conversationsFuture = _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadConversations() async {
    if (await Permission.sms.request().isGranted) {
      return _smsService.getConversations();
    } else {
      return [];
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.difference(date).inDays < 1) {
      return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    } else {
      return "${date.month}/${date.day}";
    }
  }

  void _showNewMessageDialog() {
    final TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252532),
        title: const Text('New Message', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter phone number(s) (comma separated)',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (_controller.text.isNotEmpty) {
                Navigator.pop(context);
                if (widget.onConversationSelected != null) {
                  // Pass null threadId for new conversation
                  widget.onConversationSelected!(null, _controller.text);
                }
              }
            },
            child: const Text('Start Chat', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Container(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
      child: SafeArea(
        child: Column(
          children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (_showArchived)
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _showArchived = false;
                          });
                        },
                      )
                    else
                      Image.asset(
                        'assets/images/logo.png',
                        height: 32,
                        width: 32,
                      ),
                    const SizedBox(width: 12),
                    Text(
                      _showArchived ? 'Archived' : 'Tala',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
                // Settings Button moved to Top Right
                IconButton(
                  icon: const Icon(Icons.settings, size: 24),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF252532),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, size: 20, color: Colors.grey),
                  hintText: 'Search',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Conversation List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _conversationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No conversations found'));
                }

                final allConversations = snapshot.data!;
                final conversations = allConversations.where((conv) {
                  final isArchived = settings.archivedThreads.contains(conv['threadId']);
                  if (_showArchived != isArchived) return false;

                  final address = (conv['address'] as String? ?? '').toLowerCase();
                  final snippet = (conv['snippet'] as String? ?? '').toLowerCase();
                  final contactName = settings.contactService.getNameForNumber(conv['address'] as String? ?? '')?.toLowerCase() ?? '';
                  
                  return address.contains(_searchQuery) || snippet.contains(_searchQuery) || contactName.contains(_searchQuery);
                }).toList();

                if (conversations.isEmpty) {
                  return Center(
                    child: Text(
                      _showArchived ? 'No archived chats' : 'No chats found',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final thread = conversations[index];
                    final address = thread['address'] as String? ?? 'Unknown';
                    final snippet = thread['snippet'] as String? ?? '';
                    final date = DateTime.fromMillisecondsSinceEpoch(thread['date'] as int? ?? 0);
                    final threadId = (thread['threadId'] as int? ?? 0).toString();
                    final read = (thread['read'] as int? ?? 1) == 1;

                    // Resolve contact name
                    final contactName = Provider.of<SettingsProvider>(context, listen: false).contactService.getNameForNumber(address);
                    final displayName = contactName ?? address;
                    
                    return Dismissible(
                      key: Key(threadId),
                      background: Container(
                        color: Colors.green,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: Icon(_showArchived ? Icons.unarchive : Icons.archive, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          // Archive/Unarchive (Swipe Right)
                          if (_showArchived) {
                            // Unarchive
                            await settings.unarchiveThread(threadId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Conversation unarchived')),
                            );
                          } else {
                            // Archive
                            await settings.archiveThread(threadId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Conversation archived')),
                            );
                          }
                          // Rebuild the list to reflect the change
                          setState(() {
                            _conversationsFuture = _loadConversations(); // Reload to update list
                          });
                          return false; // Don't remove from tree immediately, let rebuild handle it
                        } else {
                          // Delete (Swipe Left)
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              icon: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                              ),
                              backgroundColor: const Color(0xFF252532),
                              title: const Text('Delete Conversation?', style: TextStyle(color: Colors.white)),
                              content: const Text(
                                'This will permanently delete this conversation.',
                                style: TextStyle(color: Colors.grey),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await settings.deleteThread(threadId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Conversation deleted')),
                            );
                            setState(() {
                              _conversationsFuture = _loadConversations();
                            });
                            return true;
                          }
                          return false;
                        }
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(
                          displayName,
                          style: TextStyle(
                            fontWeight: read ? FontWeight.normal : FontWeight.bold,
                            color: read ? Colors.white70 : Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          snippet,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: read ? Colors.grey : Colors.white70,
                            fontWeight: read ? FontWeight.normal : FontWeight.w500,
                          ),
                        ),
                        trailing: Text(
                          _formatDate(date),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        onTap: () => widget.onConversationSelected?.call(threadId, address),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // User Profile & Bottom Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        );
                      },
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFF252532),
                        backgroundImage: settings.userProfileImagePath.isNotEmpty
                            ? FileImage(File(settings.userProfileImagePath))
                            : null,
                        child: settings.userProfileImagePath.isEmpty
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settings.userName.isNotEmpty ? settings.userName : 'User',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (settings.userPhone.isNotEmpty)
                            Text(
                              settings.userPhone,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Archive Button
                    IconButton(
                      icon: Icon(_showArchived ? Icons.inbox : Icons.archive, size: 24),
                      tooltip: _showArchived ? 'Show Inbox' : 'Show Archived',
                      onPressed: () {
                        setState(() {
                          _showArchived = !_showArchived;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    // New Message Button
                    IconButton(
                      icon: const Icon(Icons.add_circle, size: 32, color: Colors.tealAccent),
                      onPressed: _showNewMessageDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
