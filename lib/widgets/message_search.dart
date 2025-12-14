import 'package:flutter/material.dart';
import '../services/message_service.dart';
import '../services/haptic_service.dart';

class MessageSearch extends StatefulWidget {
  const MessageSearch({Key? key}) : super(key: key);

  @override
  State<MessageSearch> createState() => _MessageSearchState();
}

class _MessageSearchState extends State<MessageSearch> {
  final TextEditingController _searchController = TextEditingController();
  final MessageService _messageService = MessageService();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = await _messageService.searchMessages(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search messages...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          onChanged: _performSearch,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              HapticService().light();
              _searchController.clear();
              _performSearch('');
            },
          ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
              ? const Center(
                  child: Text(
                    'No messages found',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return ListTile(
                      title: Text(result['sender'] ?? 'Unknown'),
                      subtitle: Text(
                        result['message'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        result['date'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      onTap: () {
                        HapticService().light();
                        Navigator.pop(context, result);
                      },
                    );
                  },
                ),
    );
  }
}