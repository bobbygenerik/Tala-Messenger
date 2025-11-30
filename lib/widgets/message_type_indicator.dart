import 'package:flutter/material.dart';

enum MessageType { sms, rcs, iMessage }

class MessageTypeIndicator extends StatelessWidget {
  final MessageType type;
  final double size;

  const MessageTypeIndicator({
    super.key,
    required this.type,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData? icon;

    switch (type) {
      case MessageType.sms:
        color = Colors.green;
        text = 'SMS';
        icon = Icons.sms;
        break;
      case MessageType.rcs:
        color = Colors.blue; // Google Blue-ish
        text = 'RCS';
        icon = Icons.chat_bubble;
        break;
      case MessageType.iMessage:
        color = const Color(0xFF007AFF); // Apple Blue
        text = 'iMessage';
        icon = Icons.apple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: size * 0.7, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: size * 0.7,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
