import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_state.dart';
import '../theme.dart';

class ChatAppBar extends StatelessWidget {
  final AppState state;
  const ChatAppBar({super.key, required this.state});

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
