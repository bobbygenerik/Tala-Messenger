import 'package:flutter/material.dart';
import '../widgets/sidebar.dart';
import '../widgets/chat_area.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedThreadId;
  String? _selectedThreadName;

  void _onConversationSelected(String threadId, String name) {
    setState(() {
      _selectedThreadId = threadId;
      _selectedThreadName = name;
    });

    if (MediaQuery.of(context).size.width <= 800) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            threadId: threadId,
            threadName: name,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          // Desktop / Tablet Layout (Split View)
          return Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 320,
                  child: Sidebar(onConversationSelected: _onConversationSelected),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).dividerColor,
                ),
                Expanded(
                  child: ChatArea(
                    threadId: _selectedThreadId,
                    threadName: _selectedThreadName,
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile Layout (Navigation Stack)
          return Scaffold(
            body: Sidebar(
              onConversationSelected: _onConversationSelected,
            ),
          );
        }
      },
    );
  }
}

class ChatScreen extends StatelessWidget {
  final String threadId;
  final String threadName;

  const ChatScreen({super.key, required this.threadId, required this.threadName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(threadName),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: ChatArea(
        threadId: threadId,
        threadName: threadName,
      ),
    );
  }
}
