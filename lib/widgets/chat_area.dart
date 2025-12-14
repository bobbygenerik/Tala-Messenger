import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sms_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/message_service.dart';
import '../services/media_service.dart';
import '../widgets/message_reactions.dart';
import 'package:flutter/services.dart';
import '../widgets/media_viewer.dart';
import '../widgets/message_search.dart';

class ChatArea extends StatefulWidget {
  final String? threadId;
  final String? threadName;

  const ChatArea({super.key, this.threadId, this.threadName});

  @override
  State<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<ChatArea> { // State
  final TextEditingController _controller = TextEditingController();
  final SmsService _smsService = SmsService();
  final MessageService _messageService = MessageService();
  final MediaService _mediaService = MediaService();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  Timer? _delayTimer;
  // Media & Voice
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _recordedPath;
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _replyToMessage;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void didUpdateWidget(covariant ChatArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.threadId != oldWidget.threadId) {
      _loadMessages();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    // _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (widget.threadId != null) {
      setState(() => _isLoading = true);
      final msgs = await _smsService.getMessages(widget.threadId!);
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(msgs);
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _messages = [];
          _isLoading = false;
        });
      }
    }
  }

  void _sendMessage({bool delayed = false}) {
    if (_controller.text.isEmpty && _recordedPath == null) return;

    String message = _controller.text;
    if (_replyToMessage != null) {
      message = "Replying to: \"${_replyToMessage!['body']}\"\n$message";
    }

    final address = widget.threadName; // Assuming threadName is address for now

    if (address == null) return;

    if (delayed) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sending in 5 seconds...'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              _delayTimer?.cancel();
            },
          ),
        ),
      );

      _delayTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          _performSend(address, message);
          setState(() {
            _replyToMessage = null;
          });
        }
      });
    } else {
      _performSend(address, message);
      setState(() {
        _replyToMessage = null;
      });
    }
  }

  Future<void> _performSend(String address, String message) async {
    // Handle multiple recipients (simple comma separation)
    final recipients = address.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    if (recipients.isEmpty) return;

    // Optimistic UI Update
    final now = DateTime.now().millisecondsSinceEpoch;
    final tempMsg = {
      'body': message,
      'date': now,
      'isMe': true,
      'status': 0, // Sending
      'address': address,
    };

    setState(() {
      _messages.insert(0, tempMsg);
    });
    _controller.clear();

    for (final recipient in recipients) {
      await _smsService.sendSms(recipient, message);
    }

    // Refresh messages to get actual ID/status if needed, but for now just keep the optimistic one
    // Or reload silently
    _loadMessages();
  }

  Future<void> _handleAttachment(String value) async {
    if (value == 'camera') {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) _sendMedia(photo.path, 'image/jpeg');
    } else if (value == 'gallery') {
      final XFile? media = await _picker.pickMedia(); // Image or Video
      if (media != null) {
        // Simple MIME type guess
        final mime = media.path.endsWith('.mp4') ? 'video/mp4' : 'image/jpeg';
        _sendMedia(media.path, mime);
      }
    } else if (value == 'location') {
      _sendLocation();
    }
  }

  Future<void> _startRecording() async {
    final path = await _mediaService.startRecording();
    if (path != null) {
      setState(() {
        _isRecording = true;
        _recordedPath = path;
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    final path = await _mediaService.stopRecording();
    setState(() {
      _isRecording = false;
    });
    if (path != null) {
      _sendMedia(path, 'audio/aac');
    }
  }

  Future<void> _sendMedia(String path, String mimeType) async {
    final address = widget.threadName;
    if (address == null) return;
    
    // In a real app, we would use MMS. Here we will simulate or use a platform channel if implemented.
    // For now, let's just send a text message with a special prefix so our app recognizes it.
    // "MMS:<mime>:<path>"
    // NOTE: This is a hack for the demo since true MMS is hard.
    // Ideally we call _smsService.sendMms(address, path, mimeType);
    
    await _smsService.sendSms(address, "MMS:$mimeType:$path");
    _loadMessages();
  }

  Future<void> _sendLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      final position = await Geolocator.getCurrentPosition();
      final link = "https://maps.google.com/?q=${position.latitude},${position.longitude}";
      _sendMessageText(link);
    }
  }

  void _sendMessageText(String text) {
    _controller.text = text;
    _sendMessage();
  }

  void _showForwardDialog(String messageText) {
    final TextEditingController recipientController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252532),
        title: const Text('Forward Message', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Message: "$messageText"',
              style: const TextStyle(color: Colors.grey),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: recipientController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Recipient',
                labelStyle: TextStyle(color: Colors.grey),
                hintText: 'Phone number',
                hintStyle: TextStyle(color: Colors.grey),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (recipientController.text.isNotEmpty) {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                await _smsService.sendSms(recipientController.text, messageText);
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Message forwarded')),
                );
              }
            },
            child: const Text('Forward'),
          ),
        ],
      ),
    );
  }

  void _showVideoCallOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252532),
        title: const Text('Video Call', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose a video calling app:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.blue),
              title: const Text('Google Meet', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _smsService.launchVideoCall('com.google.android.apps.meetings', widget.threadName!);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_call, color: Colors.green),
              title: const Text('WhatsApp', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _smsService.launchVideoCall('com.whatsapp', widget.threadName!);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.purple),
              title: const Text('Zoom', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _smsService.launchVideoCall('us.zoom.videomeetings', widget.threadName!);
              },
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
              Navigator.pushNamed(context, '/settings');
            },
            child: const Text('Configure in Settings'),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252532),
        title: const Text('Delete Message', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this message?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _messages.removeWhere((msg) => msg['id'] == message['id']);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    HapticService().light();
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy'),
            onTap: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: message['body'] ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message copied to clipboard')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.forward),
            title: const Text('Forward'),
            onTap: () {
              Navigator.pop(context);
              _showForwardDialog(message['body'] ?? '');
            },
          ),
          ListTile(
            leading: const Icon(Icons.push_pin),
            title: const Text('Pin'),
            onTap: () async {
              Navigator.pop(context);
              await _messageService.pinMessage(message['id']?.toString() ?? '');
            },
          ),
          if (message['isMe'] == true)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (widget.threadName == null) {
      return const Center(child: Text('Select a conversation', style: TextStyle(color: Colors.grey)));
    }

    // Resolve contact name
    final contactName = Provider.of<SettingsProvider>(context).contactService.getNameForNumber(widget.threadName!);
    final displayName = contactName ?? widget.threadName!;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(displayName),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Number: ${widget.threadName}'),
                    const SizedBox(height: 8),
                    const Text('Status: Online'), // Placeholder
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                ],
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () {
              final provider = Provider.of<SettingsProvider>(context, listen: false);
              if (provider.callAppPackage.isNotEmpty) {
                _smsService.launchApp(provider.callAppPackage);
              } else {
                launchUrl(Uri.parse("tel:${widget.threadName}"));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              final provider = Provider.of<SettingsProvider>(context, listen: false);
              if (provider.videoCallAppPackage.isNotEmpty) {
                _smsService.launchVideoCall(provider.videoCallAppPackage, widget.threadName!);
              } else {
                _showVideoCallOptions();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              HapticService().light();
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MessageSearch()),
              );
              if (result != null) {
                // Navigate to message
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
        // Messages List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(child: Text('No messages', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(24.0),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return Dismissible(
                          key: Key(msg['id']?.toString() ?? index.toString()),
                          direction: DismissDirection.startToEnd,
                          onDismissed: (direction) {
                            setState(() {
                              _replyToMessage = msg;
                            });
                          },
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            color: Colors.transparent,
                            child: const Icon(Icons.reply, color: Colors.grey),
                          ),
                          child: MessageBubble(
                            messageId: msg['id']?.toString() ?? index.toString(),
                            text: msg['body'] ?? '',
                            time: DateTime.fromMillisecondsSinceEpoch(msg['date'] ?? 0).toString().split(' ')[1].substring(0, 5),
                            isMe: msg['isMe'] ?? false,
                            status: msg['status'] ?? -1,
                            onLongPress: () => _showMessageOptions(msg),
                          ),
                        );
                      },
                    ),
        ),
          // Reply Preview
          if (_replyToMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Replying to: ${_replyToMessage!['body']}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _replyToMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          // Input Area
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF252532),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.attach_file, color: Colors.grey),
                      onSelected: (value) => _handleAttachment(value),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'camera', child: Row(children: [Icon(Icons.camera_alt), SizedBox(width: 8), Text('Camera')])),
                        const PopupMenuItem(value: 'gallery', child: Row(children: [Icon(Icons.image), SizedBox(width: 8), Text('Gallery')])),
                        const PopupMenuItem(value: 'location', child: Row(children: [Icon(Icons.location_on), SizedBox(width: 8), Text('Location')])),
                      ],
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: _isRecording ? 'Recording...' : 'Type a message...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: _isRecording ? Colors.red : Colors.grey),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onLongPressStart: (_) => _startRecording(),
                      onLongPressEnd: (_) => _stopRecording(),
                      child: IconButton(
                        icon: Icon(_isRecording ? Icons.mic : Icons.mic_none, color: _isRecording ? Colors.red : Colors.grey),
                        onPressed: () {
                          if (_controller.text.isNotEmpty) {
                            // If text is present, this button could be send, but we have a dedicated send button.
                            // Maybe toggle between mic and send? For now, keep separate.
                          }
                        },
                      ),
                    ),
                    GestureDetector(
                      onLongPress: () => _sendMessage(delayed: true),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send, size: 18, color: Colors.white),
                          onPressed: () {
                            HapticService().medium();
                            _sendMessage(delayed: false);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String messageId;
  final String text;
  final String time;
  final bool isMe;
  final int status;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.messageId,
    required this.text,
    required this.time,
    required this.isMe,
    this.status = -1,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Check for "MMS" prefix hack
    bool isMms = text.startsWith("MMS:");
    String? mimeType;
    String? mediaPath;
    
    if (isMms) {
      final parts = text.split(':');
      if (parts.length >= 3) {
        mimeType = parts[1];
        mediaPath = parts.sublist(2).join(':'); // Rejoin path if it contained colons
      }
    }

    // Check for Location link
    bool isLocation = text.contains("maps.google.com");

    Widget content;
    if (isMms && mediaPath != null) {
      if (mimeType?.startsWith('image') ?? false) {
        content = GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaViewer(
                  mediaPath: mediaPath!,
                  mediaType: 'image',
                ),
              ),
            );
          },
          child: Image.file(File(mediaPath), width: 200, fit: BoxFit.cover),
        );
      } else if (mimeType?.startsWith('video') ?? false) {
        content = GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaViewer(
                  mediaPath: mediaPath!,
                  mediaType: 'video',
                ),
              ),
            );
          },
          child: const Icon(Icons.videocam, size: 48, color: Colors.white),
        );
      } else if (mimeType?.startsWith('audio') ?? false) {
        content = const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, color: Colors.white),
            SizedBox(width: 8),
            Text('Audio Message', style: TextStyle(color: Colors.white)),
          ],
        );
      } else {
        content = Text(text, style: const TextStyle(color: Colors.white));
      }
    } else if (isLocation) {
      content = GestureDetector(
        onTap: () => launchUrl(Uri.parse(text)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.map, color: Colors.white),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
          ],
        ),
      );
    } else {
      content = Text(text, style: const TextStyle(color: Colors.white));
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        )
                      : null,
                  color: isMe ? null : const Color(0xFF252532),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: content,
              ),
              MessageReactions(messageId: messageId),
              Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    if (isMe && status != -1) ...[
                      const SizedBox(width: 4),
                      Icon(
                        status == 0 ? Icons.check : Icons.done_all, 
                        size: 12,
                        color: status == 0 ? Colors.blue : Colors.grey,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
