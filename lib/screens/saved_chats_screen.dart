import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';

class SavedChatsScreen extends StatelessWidget {
  const SavedChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Chats'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_outline,
              size: 64,
              color: ZubiaColors.textMuted,
            ),
            SizedBox(height: 16),
            Text(
              'No saved chats yet',
              style: TextStyle(fontSize: 18, color: ZubiaColors.textSecondary),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the heart on a chat to save it',
              style: TextStyle(color: ZubiaColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
