import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_state.dart';
import '../theme.dart';

class ChatAppBar extends StatelessWidget {
  final AppState state;
  const ChatAppBar({super.key, required this.state});

  Future<void> _confirmClearSaved(BuildContext context) async {
    if (state.savedPhrases.isEmpty) return;
    final snapshot = List<SavedPhrase>.from(state.savedPhrases);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear saved phrases?'),
          content: const Text(
            'This will remove all saved phrases from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear all'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await state.clearSavedPhrases();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Cleared all saved phrases'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            state.restoreSavedPhrases(snapshot);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: ZubiaColors.charcoalMid,
        border: Border(bottom: BorderSide(color: ZubiaColors.glassBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            tooltip: 'Back to Home',
            onPressed: () {
              state.leaveThread();
              context.go('/home');
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.otherUserName ?? 'Chat',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _StatusDot(status: state.connectionStatus),
                    const SizedBox(width: 4),
                    Text(
                      _statusLabel(state.connectionStatus),
                      style: const TextStyle(
                        fontSize: 12,
                        color: ZubiaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open Saved Phrases (long-press to clear all)',
            onPressed: () => context.go('/saved'),
            onLongPress: () => _confirmClearSaved(context),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.bookmark_border, size: 22),
                if (state.savedPhrases.isNotEmpty)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: ZubiaColors.magenta,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        state.savedPhrases.length > 99
                            ? '99+'
                            : state.savedPhrases.length.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'connected':
        return 'Connected';
      case 'recording':
        return 'Recording...';
      case 'processing':
        return 'Translating...';
      case 'connecting':
        return 'Connecting...';
      default:
        return 'Disconnected';
    }
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'connected':
        color = ZubiaColors.success;
        break;
      case 'recording':
        color = ZubiaColors.danger;
        break;
      case 'processing':
        color = ZubiaColors.warning;
        break;
      default:
        color = ZubiaColors.textMuted;
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
