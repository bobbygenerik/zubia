import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/nav_item.dart';
import '../widgets/zubia_logo.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  static const String _swipeHintSeenKey = 'savedSwipeHintSeenV1';
  bool _showSwipeHint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadSavedPhrases();
    });
    _initSwipeHint();
  }

  Future<void> _initSwipeHint() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_swipeHintSeenKey) ?? false;
    if (seen) return;

    await prefs.setBool(_swipeHintSeenKey, true);
    if (!mounted) return;
    setState(() => _showSwipeHint = true);
  }

  Future<void> _removePhrase(SavedPhrase phrase, {int atIndex = 0}) async {
    HapticFeedback.selectionClick();
    final state = context.read<AppState>();
    await state.removeSavedPhrase(phrase);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Removed from saved'),
        duration: const Duration(milliseconds: 2200),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            state.addSavedPhraseEntry(phrase, atIndex: atIndex);
          },
        ),
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    final state = context.read<AppState>();
    if (state.savedPhrases.isEmpty) return;
    final snapshot = List<SavedPhrase>.from(state.savedPhrases);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear saved phrases?'),
          content: const Text('This will remove all saved phrases.'),
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Cleared all saved phrases'),
        duration: const Duration(milliseconds: 3000),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            state.restoreSavedPhrases(snapshot);
          },
        ),
      ),
    );
  }

  String _createdLabel(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.month}/${dt.day} $h:$m $ampm';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = state.savedPhrases;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: ZubiaColors.charcoalMid,
                border: const Border(
                  bottom: BorderSide(color: ZubiaColors.glassBorder),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    tooltip: 'Back to Home',
                    onPressed: () => context.go('/home'),
                  ),
                  const SizedBox(width: 24, height: 24, child: ZubiaLogo()),
                  const SizedBox(width: 10),
                  const Text(
                    'Saved',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, size: 22),
                    tooltip: 'Clear all saved phrases',
                    onPressed: items.isEmpty ? null : _confirmClearAll,
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          'No saved items yet.\nSave phrases and translations to find them here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ZubiaColors.textMuted,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      children: [
                        if (_showSwipeHint)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: ZubiaColors.magenta.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ZubiaColors.magenta.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.swipe_left,
                                  size: 18,
                                  color: ZubiaColors.magenta,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Tip: Swipe a card left to delete quickly',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ZubiaColors.textSecondary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  color: ZubiaColors.textMuted,
                                  tooltip: 'Dismiss hint',
                                  onPressed: () {
                                    setState(() => _showSwipeHint = false);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ...List.generate(items.length, (index) {
                          final p = items[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Dismissible(
                              key: ValueKey(
                                '${p.createdAt}|${p.originalText}|${p.toLanguage}',
                              ),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: ZubiaColors.danger.withValues(
                                    alpha: 0.85,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.centerRight,
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              onDismissed: (_) =>
                                  _removePhrase(p, atIndex: index),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: ZubiaColors.surfaceCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${state.getFlagEmoji(p.fromLanguage)} ${p.fromLanguage.toUpperCase()}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: ZubiaColors.textSecondary,
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                          child: Icon(
                                            Icons.arrow_forward,
                                            size: 14,
                                            color: ZubiaColors.textMuted,
                                          ),
                                        ),
                                        Text(
                                          '${state.getFlagEmoji(p.toLanguage)} ${p.toLanguage.toUpperCase()}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: ZubiaColors.textSecondary,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _createdLabel(p.createdAt),
                                          style: const TextStyle(
                                            color: ZubiaColors.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '"${p.originalText}"',
                                      style: const TextStyle(
                                        height: 1.35,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '"${p.translatedText}"',
                                      style: TextStyle(
                                        height: 1.35,
                                        color: ZubiaColors.magenta.withValues(
                                          alpha: 0.85,
                                        ),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        onPressed: () =>
                                            _removePhrase(p, atIndex: index),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: ZubiaColors.textMuted,
                                        ),
                                        tooltip: 'Remove saved phrase',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
            ),
            _BottomNav(),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
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
            ZubiaNavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              active: false,
              onTap: () => context.go('/home'),
            ),
            ZubiaNavItem(
              icon: Icons.history,
              label: 'History',
              active: false,
              onTap: () => context.go('/history'),
            ),
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZubiaColors.charcoalDark,
                border: Border.all(
                  color: ZubiaColors.magenta.withValues(alpha: 0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ZubiaColors.magenta.withValues(alpha: 0.15),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const SizedBox(width: 36, height: 36, child: ZubiaLogo()),
            ),
            ZubiaNavItem(
              icon: Icons.favorite,
              label: 'Saved',
              active: true,
              onTap: () {},
            ),
            ZubiaNavItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              active: false,
              onTap: () => context.go('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}
