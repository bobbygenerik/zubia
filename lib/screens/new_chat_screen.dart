import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final state = context.read<AppState>();
    final users = await state.api.getUsers();

    if (state.userId != null) {
      _users = users.where((u) => u['id'] != state.userId).toList();
    } else {
      _users = users;
    }
    _filteredUsers = _users;

    if (mounted) setState(() => _isLoading = false);
  }

  void _filter(String query) {
    if (query.isEmpty) {
      _filteredUsers = _users;
    } else {
      _filteredUsers = _users
          .where(
            (u) => (u['name'] as String).toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();
    }
    setState(() {});
  }

  Future<void> _startThread(String otherUserId, String otherUserName) async {
    final state = context.read<AppState>();
    setState(() => _isLoading = true);

    final threadId = await state.createThreadWithUser(otherUserId);
    if (threadId != null && mounted) {
      state.joinThread(threadId, otherUserName);
      context.go('/chat');
    } else if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to create chat')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: ZubiaColors.textMuted,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: ZubiaColors.magenta,
                    ),
                  )
                : _filteredUsers.isEmpty
                ? const Center(
                    child: Text(
                      'No users found.',
                      style: TextStyle(color: ZubiaColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final u = _filteredUsers[index];
                      final name = u['name'] ?? 'Unknown';
                      final lang = u['language'] ?? 'en';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: ZubiaColors.magenta.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            state.getFlagEmoji(lang),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Speaks ${state.languages[lang] ?? lang}',
                          style: TextStyle(
                            color: ZubiaColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        onTap: () => _startThread(u['id'], name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
