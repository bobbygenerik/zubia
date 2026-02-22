import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/zubia_logo.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    state.loadLanguages();
    state.loadRooms();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool get _canJoin => _nameController.text.trim().isNotEmpty && _codeController.text.trim().isNotEmpty;

  void _joinRoom() {
    final state = context.read<AppState>();
    state.userName = _nameController.text.trim();
    state.joinRoom(_codeController.text.trim());
    context.go('/chat');
  }

  Future<void> _createRoom() async {
    if (_nameController.text.trim().isEmpty) return;
    final state = context.read<AppState>();
    state.userName = _nameController.text.trim();
    final roomId = await state.createRoom();
    if (roomId != null && mounted) {
      state.joinRoom(roomId);
      context.go('/chat');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, state, _) {
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Zubia', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text('Speak your language. Hear theirs.', style: TextStyle(fontSize: 14, color: ZubiaColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Join Room Card
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.meeting_room_outlined, color: ZubiaColors.magenta, size: 18),
                                const SizedBox(width: 8),
                                const Text('Join a Room', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              ]),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _nameController,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: 'Your name',
                                  prefixIcon: Icon(Icons.person_outline, size: 20),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: state.userLanguage.isNotEmpty ? state.userLanguage : 'en',
                                dropdownColor: ZubiaColors.charcoalLight,
                                decoration: const InputDecoration(
                                  hintText: 'Language',
                                  prefixIcon: Icon(Icons.language, size: 20),
                                ),
                                items: state.languages.entries.map((e) {
                                  return DropdownMenuItem(
                                    value: e.key,
                                    child: Text('${state.getFlagEmoji(e.key)} ${e.value}'),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) state.changeLanguage(v);
                                },
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _codeController,
                                onChanged: (_) => setState(() {}),
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  hintText: 'Room code',
                                  prefixIcon: Icon(Icons.tag, size: 20),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _canJoin ? _joinRoom : null,
                                      child: const Text('Join Room'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _GradientButton(
                                      onTap: _nameController.text.trim().isNotEmpty ? _createRoom : null,
                                      label: 'Create New',
                                      icon: Icons.add_circle_outline,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Active Rooms
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.group_outlined, color: ZubiaColors.magenta, size: 18),
                                const SizedBox(width: 8),
                                const Text('Active Rooms', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              ]),
                              const SizedBox(height: 12),
                              if (state.activeRooms.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Text('No active rooms. Create one!', style: TextStyle(color: ZubiaColors.textMuted)),
                                  ),
                                )
                              else
                                ...state.activeRooms.map((room) => _RoomTile(
                                      name: room['name'] ?? '',
                                      id: room['id'] ?? '',
                                      userCount: room['userCount'] ?? 0,
                                      onTap: () {
                                        _codeController.text = room['id'] ?? '';
                                        setState(() {});
                                        if (_nameController.text.trim().isNotEmpty) _joinRoom();
                                      },
                                    )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom Nav
                _BottomNav(currentIndex: 0),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZubiaColors.glassBorder),
      ),
      child: child,
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final IconData icon;
  const _GradientButton({this.onTap, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: onTap != null ? ZubiaColors.magentaGradient : null,
          color: onTap == null ? Colors.white.withValues(alpha: 0.05) : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: onTap != null
              ? [BoxShadow(color: ZubiaColors.magenta.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: onTap != null ? Colors.white : ZubiaColors.textMuted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: onTap != null ? Colors.white : ZubiaColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final String name, id;
  final int userCount;
  final VoidCallback onTap;
  const _RoomTile({required this.name, required this.id, required this.userCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(id, style: TextStyle(fontSize: 12, color: ZubiaColors.textMuted, fontFamily: 'monospace')),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ZubiaColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: ZubiaColors.success, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('$userCount', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: ZubiaColors.charcoalDark.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: ZubiaColors.glassBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.home_outlined, label: 'Home', active: currentIndex == 0, onTap: () => context.go('/lobby')),
            _NavItem(icon: Icons.history, label: 'History', active: currentIndex == 1, onTap: () => context.go('/history')),
            // Center Z logo
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZubiaColors.charcoalDark,
                border: Border.all(color: ZubiaColors.magenta.withValues(alpha: 0.2), width: 2),
                boxShadow: [BoxShadow(color: ZubiaColors.magenta.withValues(alpha: 0.15), blurRadius: 16)],
              ),
              child: const SizedBox(width: 36, height: 36, child: ZubiaLogo()),
            ),
            _NavItem(icon: Icons.favorite_outline, label: 'Saved', active: currentIndex == 2, onTap: () {}),
            _NavItem(icon: Icons.settings_outlined, label: 'Settings', active: currentIndex == 3, onTap: () {}),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: active ? ZubiaColors.magenta : ZubiaColors.textMuted),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: active ? ZubiaColors.magenta : ZubiaColors.textMuted)),
        ],
      ),
    );
  }
}
