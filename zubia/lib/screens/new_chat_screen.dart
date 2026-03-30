import 'dart:async';
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
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  bool _isStarting = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(query.trim());
    });
  }

  Future<void> _search(String query) async {
    final state = context.read<AppState>();
    setState(() => _isSearching = true);
    final users = await state.api.searchUsers(query);
    if (!mounted) return;
    setState(() {
      _results = users.where((u) => u['id'] != state.userId).toList();
      _isSearching = false;
    });
  }

  Future<void> _startThread(String otherUserId, String otherUserName) async {
    if (_isStarting) return;

    final state = context.read<AppState>();
    setState(() => _isStarting = true);

    final threadId = await state.createThreadWithUser(otherUserId);
    if (threadId != null && mounted) {
      state.joinThread(threadId, otherUserName);
      context.go('/chat');
    } else if (mounted) {
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to create chat. Please try again.'),
          action: SnackBarAction(
            label: 'RETRY',
            onPressed: () => _startThread(otherUserId, otherUserName),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isStarting
          ? const Center(
              child: CircularProgressIndicator(color: ZubiaColors.magenta),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by username...',
                      prefixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ZubiaColors.magenta,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.search,
                              color: ZubiaColors.textMuted,
                            ),
                      suffixIcon: hasQuery
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: ZubiaColors.textMuted,
                                size: 20,
                              ),
                              tooltip: 'Clear',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _results = []);
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: !hasQuery
                      ? const Center(
                          child: Text(
                            'Search for someone to chat with',
                            style: TextStyle(color: ZubiaColors.textMuted),
                          ),
                        )
                      : _results.isEmpty && !_isSearching
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: ZubiaColors.textMuted,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No users match "${_searchController.text.trim()}"',
                                style: const TextStyle(
                                  color: ZubiaColors.textMuted,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _results = []);
                                },
                                child: const Text('Clear Search'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final u = _results[index];
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Speaks ${state.languages[lang] ?? lang}',
                                style: const TextStyle(
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
