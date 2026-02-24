import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/chat_app_bar.dart';

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
                ChatAppBar(state: state),

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

// ─── Feed Items ───────────────────────────────────

class _FeedItem extends StatelessWidget {
  final FeedEntry entry;
  final AppState state;
  const _FeedItem({required this.entry, required this.state});

  @override
  Widget build(BuildContext context) {
    if (entry.type == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Flexible(child: Text(entry.systemText ?? '', style: TextStyle(color: ZubiaColors.textSecondary, fontSize: 12), textAlign: TextAlign.center)),
          ],
        ),
      );
    }

    final isMe = entry.fromUser == state.userName;
    final initial = (entry.fromUser ?? '?')[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: ZubiaColors.magenta.withValues(alpha: 0.15),
              child: Text(initial, style: const TextStyle(color: ZubiaColors.magenta, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isMe ? ZubiaColors.magenta.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border.all(
                  color: isMe ? ZubiaColors.magenta.withValues(alpha: 0.3) : ZubiaColors.glassBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(entry.fromUser ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ZubiaColors.textSecondary)),
                        const SizedBox(width: 6),
                        if (entry.fromLanguage != null)
                          Text(state.getFlagEmoji(entry.fromLanguage!), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (entry.originalText != null && !isMe) ...[
                    Text('"${entry.originalText}"', style: TextStyle(color: ZubiaColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 4),
                  ],
                  if (entry.translatedText != null && !isMe)
                    Text(entry.translatedText!, style: const TextStyle(fontSize: 15))
                  else if (isMe && entry.originalText != null)
                    Text(entry.originalText!, style: const TextStyle(fontSize: 15))
                  else if (isMe && entry.translatedText != null)
                    Text(entry.translatedText!, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: ZubiaColors.success.withValues(alpha: 0.15),
              child: Text(initial, style: const TextStyle(color: ZubiaColors.success, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ],
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
                child: Semantics(
                  button: true,
                  label: 'Real-time mode',
                  selected: state.mode == 'realtime',
                  child: Tooltip(
                    message: 'Switch to Real-time mode',
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
                ),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Walkie-talkie mode',
                  selected: state.mode == 'walkie',
                  child: Tooltip(
                    message: 'Switch to Walkie-talkie mode',
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

    final semanticLabel = isWalkie
        ? 'Walkie Talkie Microphone'
        : (recording ? 'Stop Recording' : 'Start Recording');

    final semanticHint = isWalkie
        ? 'Hold to record, release to send'
        : (recording ? 'Tap to stop recording' : 'Tap to start recording');

    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      enabled: true,
      child: Tooltip(
        message: semanticHint,
        child: GestureDetector(
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
        ),
      ),
    );
  }
}
