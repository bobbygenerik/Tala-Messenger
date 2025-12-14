import 'package:flutter/material.dart';
import '../services/message_service.dart';
import '../services/haptic_service.dart';

class MessageReactions extends StatefulWidget {
  final String messageId;
  final Function(String)? onReactionAdded;

  const MessageReactions({
    Key? key,
    required this.messageId,
    this.onReactionAdded,
  }) : super(key: key);

  @override
  State<MessageReactions> createState() => _MessageReactionsState();
}

class _MessageReactionsState extends State<MessageReactions> {
  final MessageService _messageService = MessageService();
  List<String> _reactions = [];

  @override
  void initState() {
    super.initState();
    _loadReactions();
  }

  Future<void> _loadReactions() async {
    final reactions = await _messageService.getReactions(widget.messageId);
    if (mounted) {
      setState(() {
        _reactions = reactions;
      });
    }
  }

  void _showReactionPicker() {
    HapticService().light();
    
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            left: position.dx,
            top: position.dy - 60,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF252532),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['❤️', '😂', '😮', '😢', '😡', '👍', '👎'].map((emoji) {
                    return GestureDetector(
                      onTap: () async {
                        HapticService().medium();
                        final navigator = Navigator.of(context);
                        await _messageService.addReaction(widget.messageId, emoji, 'user');
                        widget.onReactionAdded?.call(emoji);
                        navigator.pop();
                        _loadReactions();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_reactions.isEmpty) {
      return GestureDetector(
        onTap: _showReactionPicker,
        child: const Icon(Icons.add_reaction_outlined, size: 16, color: Colors.grey),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._reactions.take(3).map((reaction) {
          final parts = reaction.split(':');
          return Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(parts.length > 1 ? parts[1] : reaction, style: const TextStyle(fontSize: 12)),
          );
        }),
        if (_reactions.length > 3)
          Text('+${_reactions.length - 3}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: _showReactionPicker,
          child: const Icon(Icons.add_reaction_outlined, size: 16, color: Colors.grey),
        ),
      ],
    );
  }
}