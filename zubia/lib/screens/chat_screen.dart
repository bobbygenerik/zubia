import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_state.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _feedScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _requestMicPermission();
  }

  Future<void> _requestMicPermission() async {
    await Permission.microphone.request();
  }

  @override
  void dispose() {
    _feedScroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_feedScroll.hasClients) {
        _feedScroll.animateTo(
          _feedScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        _scrollToBottom();

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // ── App Bar ──
                _ChatAppBar(state: state),

                // ── Translation Feed ──
                Expanded(
                  child: ListView.builder(
                    controller: _feedScroll,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: state.feed.length,
                    itemBuilder: (context, i) => _FeedItem(entry: state.feed[i], state: state),
                  ),
                ),

                // ── Controls ──
                _ControlsBar(state: state),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── App Bar ──────────────────────────────────────

class _ChatAppBar extends StatelessWidget {
  final AppState state;
  const _ChatAppBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ZubiaColors.charcoalMid,
        border: const Border(bottom: BorderSide(color: ZubiaColors.glassBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () {
              state.leaveRoom();
              context.go('/lobby');
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.roomName ?? 'Room', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: ZubiaColors.magenta.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ZubiaColors.magenta.withValues(alpha: 0.2)),
                      ),
                      child: Text(state.roomId ?? '', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: ZubiaColors.magenta)),
                    ),
                    const SizedBox(width: 8),
                    _StatusDot(status: state.connectionStatus),
                    const SizedBox(width: 4),
                    Text(
                      _statusLabel(state.connectionStatus),
                      style: const TextStyle(fontSize: 12, color: ZubiaColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Participant count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_outline, size: 16, color: ZubiaColors.textSecondary),
                const SizedBox(width: 4),
                Text('${state.users.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'connected': return 'Connected';
      case 'recording': return 'Recording...';
      case 'processing': return 'Translating...';
      case 'connecting': return 'Connecting...';
      default: return 'Disconnected';
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
      case 'connected': color = ZubiaColors.success; break;
      case 'recording': color = ZubiaColors.danger; break;
      case 'processing': color = ZubiaColors.warning; break;
      default: color = ZubiaColors.textMuted;
    }
    return Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

// ─── Feed Items ───────────────────────────────────

class _FeedItem extends StatelessWidget {
  final FeedEntry entry;
  final AppState state;
  const _FeedItem({required this.entry, required this.state});

  @override
  Widget build(BuildContext context) {
    if (entry.type == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Text('⚡', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(child: Text(entry.systemText ?? '', style: TextStyle(color: ZubiaColors.textSecondary, fontSize: 13))),
          ],
        ),
      );
    }

    final initial = (entry.fromUser ?? '?')[0].toUpperCase();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZubiaColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: ZubiaColors.magenta.withValues(alpha: 0.2),
            child: Text(initial, style: const TextStyle(color: ZubiaColors.magenta, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(entry.fromUser ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(width: 8),
                    if (entry.fromLanguage != null)
                      Text(
                        '${state.getFlagEmoji(entry.fromLanguage!)} ${entry.fromLanguage!.toUpperCase()}'
                        '${entry.toLanguage != null ? ' → ${state.getFlagEmoji(entry.toLanguage!)} ${entry.toLanguage!.toUpperCase()}' : ''}',
                        style: const TextStyle(fontSize: 11, color: ZubiaColors.textMuted),
                      ),
                  ],
                ),
                if (entry.originalText != null) ...[
                  const SizedBox(height: 4),
                  Text('"${entry.originalText}"', style: TextStyle(color: ZubiaColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic)),
                ],
                if (entry.translatedText != null) ...[
                  const SizedBox(height: 4),
                  Text(entry.translatedText!, style: const TextStyle(fontSize: 14)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Controls Bar ─────────────────────────────────

class _ControlsBar extends StatelessWidget {
  final AppState state;
  const _ControlsBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: ZubiaColors.charcoalMid,
        border: const Border(top: BorderSide(color: ZubiaColors.glassBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode toggle
          _ModeToggle(state: state),
          const SizedBox(height: 12),
          // Mic button
          _MicButton(state: state),
          const SizedBox(height: 6),
          Text(
            state.mode == 'walkie'
                ? (state.isRecording ? 'Release to send' : 'Hold to talk')
                : (state.isRecording ? 'Tap to stop' : 'Tap to stream'),
            style: TextStyle(fontSize: 12, color: ZubiaColors.textMuted),
          ),
          const SizedBox(height: 8),
          // Volume
          Row(
            children: [
              const Icon(Icons.volume_down, size: 18, color: ZubiaColors.textMuted),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: ZubiaColors.magenta,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                    thumbColor: ZubiaColors.magenta,
                    overlayColor: ZubiaColors.magenta.withValues(alpha: 0.1),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: state.volume,
                    onChanged: (v) => state.setVolume(v),
                  ),
                ),
              ),
              const Icon(Icons.volume_up, size: 18, color: ZubiaColors.textMuted),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final AppState state;
  const _ModeToggle({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZubiaColors.glassBorder),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: state.mode == 'realtime' ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: state.mode == 'walkie'
                      ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEA580C)])
                      : ZubiaColors.magentaGradient,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [BoxShadow(color: ZubiaColors.magenta.withValues(alpha: 0.3), blurRadius: 8)],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => state.setMode('realtime'),
                  child: Center(
                    child: Text('Real-time', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: state.mode == 'realtime' ? Colors.white : ZubiaColors.textMuted,
                    )),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => state.setMode('walkie'),
                  child: Center(
                    child: Text('Walkie-talkie', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: state.mode == 'walkie' ? Colors.white : ZubiaColors.textMuted,
                    )),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final AppState state;
  const _MicButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final isWalkie = state.mode == 'walkie';
    final recording = state.isRecording;
    final color = isWalkie ? const Color(0xFFF59E0B) : ZubiaColors.magenta;

    return GestureDetector(
      onTap: isWalkie ? null : () {
        if (recording) {
          state.stopRecording();
        } else {
          state.startRealtimeRecording();
        }
      },
      onLongPressStart: isWalkie ? (_) => state.startWalkieRecording() : null,
      onLongPressEnd: isWalkie ? (_) => state.stopWalkieAndSend() : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: recording
              ? null
              : LinearGradient(colors: [color, color.withValues(alpha: 0.8)]),
          color: recording ? ZubiaColors.danger : null,
          boxShadow: [
            BoxShadow(
              color: (recording ? ZubiaColors.danger : color).withValues(alpha: 0.4),
              blurRadius: recording ? 24 : 16,
            ),
          ],
        ),
        child: Icon(
          recording ? Icons.stop : Icons.mic,
          size: 32,
          color: Colors.white,
        ),
      ),
    );
  }
}
