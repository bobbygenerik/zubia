import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/nav_item.dart';
import '../widgets/zubia_logo.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';

  String _getSectionLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(dt.year, dt.month, dt.day);

    if (entryDate == today) {
      return 'Today';
    } else if (entryDate == yesterday) {
      return 'Yesterday';
    } else if (entryDate.year == today.year) {
      return 'Today'; // Default for now - can be enhanced
    } else {
      return '${dt.month}/${dt.day}/${dt.year}';
    }
  }

  String _getTimeLabel(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  List<_HistoryEntry> _getFilteredEntries(List<TranslationHistory> history) {
    final q = _query.trim().toLowerCase();
    final entries = history.map((h) {
      final dt = DateTime.parse(h.createdAt).toLocal();
      return _HistoryEntry(
        section: _getSectionLabel(dt),
        fromLang: h.fromLanguage.toUpperCase(),
        toLang: h.toLanguage.toUpperCase(),
        time: _getTimeLabel(dt),
        original: h.originalText,
        translated: h.translatedText,
        isVoice: h.isVoice,
      );
    }).toList();

    if (q.isEmpty) return entries;
    return entries.where((e) {
      return e.original.toLowerCase().contains(q) ||
          e.translated.toLowerCase().contains(q) ||
          e.fromLang.toLowerCase().contains(q) ||
          e.toLang.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openSearchDialog() async {
    final controller = TextEditingController(text: _query);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: ZubiaColors.charcoalMid,
          title: const Text('Search history'),
          content: TextField(
            controller: controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search by phrase or language...',
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() => _query = result.trim());
  }

  void _handlePlaybackTap(_HistoryEntry entry) {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing: "${entry.original}"'),
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  Future<void> _toggleSaved(_HistoryEntry entry) async {
    final state = context.read<AppState>();
    final wasSaved = state.isPhraseSaved(
      originalText: entry.original,
      translatedText: entry.translated,
      fromLanguage: entry.fromLang.toLowerCase(),
      toLanguage: entry.toLang.toLowerCase(),
    );

    await state.toggleSavedPhrase(
      originalText: entry.original,
      translatedText: entry.translated,
      fromLanguage: entry.fromLang.toLowerCase(),
      toLanguage: entry.toLang.toLowerCase(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasSaved ? 'Removed from saved' : 'Saved for quick access',
        ),
        duration: const Duration(milliseconds: 1100),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entries = _getFilteredEntries(appState.history);
    final List<Widget> historyWidgets = [];
    String? previousSection;

    for (final entry in entries) {
      if (previousSection != entry.section) {
        historyWidgets.add(_DateDivider(label: entry.section));
        previousSection = entry.section;
      }
      final isSaved = appState.isPhraseSaved(
        originalText: entry.original,
        translatedText: entry.translated,
        fromLanguage: entry.fromLang.toLowerCase(),
        toLanguage: entry.toLang.toLowerCase(),
      );
      historyWidgets.add(
        _HistoryCard(
          fromLang: entry.fromLang,
          toLang: entry.toLang,
          time: entry.time,
          original: entry.original,
          translated: entry.translated,
          isVoice: entry.isVoice,
          isSaved: isSaved,
          onToggleSaved: () => _toggleSaved(entry),
          onPlay: () => _handlePlaybackTap(entry),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App bar
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
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: ZubiaLogo(excludeFromSemantics: true),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Zubia',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search, size: 22),
                    tooltip: 'Search history',
                    onPressed: _openSearchDialog,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: entries.isEmpty
                    ? [
                        const SizedBox(height: 48),
                        _query.isNotEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: ZubiaColors.textMuted,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No history match "$_query"',
                                      style: const TextStyle(
                                        color: ZubiaColors.textMuted,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () =>
                                          setState(() => _query = ''),
                                      child: const Text('Clear Search'),
                                    ),
                                  ],
                                ),
                              )
                            : const Center(
                                child: Text(
                                  'No history results found',
                                  style: TextStyle(
                                    color: ZubiaColors.textMuted,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                      ]
                    : historyWidgets,
              ),
            ),

            // Bottom nav
            _BottomNav(),
          ],
        ),
      ),
    );
  }
}

class _HistoryEntry {
  final String section;
  final String fromLang;
  final String toLang;
  final String time;
  final String original;
  final String translated;
  final bool isVoice;

  const _HistoryEntry({
    required this.section,
    required this.fromLang,
    required this.toLang,
    required this.time,
    required this.original,
    required this.translated,
    required this.isVoice,
  });
}

class _DateDivider extends StatelessWidget {
  final String label;
  const _DateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: ZubiaColors.magenta.withValues(alpha: 0.15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ZubiaColors.magenta,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: ZubiaColors.magenta.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String fromLang, toLang, time, original, translated;
  final bool isVoice;
  final bool isSaved;
  final VoidCallback onToggleSaved;
  final VoidCallback onPlay;

  const _HistoryCard({
    required this.fromLang,
    required this.toLang,
    required this.time,
    required this.original,
    required this.translated,
    required this.isVoice,
    required this.isSaved,
    required this.onToggleSaved,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZubiaColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LangBadge(code: fromLang),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: ZubiaColors.textMuted,
                ),
              ),
              _LangBadge(code: toLang),
              const Spacer(),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  color: ZubiaColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"$original"',
            style: const TextStyle(fontWeight: FontWeight.w500, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            '"$translated"',
            style: TextStyle(
              fontSize: 13,
              color: ZubiaColors.magenta.withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: ZubiaColors.glassBorder)),
            ),
            child: Row(
              children: [
                Icon(
                  isVoice ? Icons.mic : Icons.keyboard,
                  size: 14,
                  color: ZubiaColors.magenta,
                ),
                const SizedBox(width: 6),
                Text(
                  isVoice ? 'Voice Mode' : 'Text Mode',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ZubiaColors.textMuted,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onToggleSaved,
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    size: 18,
                    color: ZubiaColors.magenta,
                  ),
                  tooltip: isSaved ? 'Remove saved' : 'Save phrase',
                ),
                Semantics(
                  button: true,
                  label: 'Play recording',
                  child: Tooltip(
                    message: 'Play recording',
                    child: GestureDetector(
                      onTap: onPlay,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ZubiaColors.magenta.withValues(alpha: 0.1),
                          border: Border.all(
                            color: ZubiaColors.magenta.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          size: 18,
                          color: ZubiaColors.magenta,
                        ),
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
}

class _LangBadge extends StatelessWidget {
  final String code;
  const _LangBadge({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ZubiaColors.magenta.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ZubiaColors.magenta.withValues(alpha: 0.3)),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: ZubiaColors.magenta,
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
              active: true,
              onTap: () {},
            ),
            Semantics(
              button: true,
              label: 'More actions',
              child: Tooltip(
                message: 'More actions',
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('More actions coming soon!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
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
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: ZubiaLogo(excludeFromSemantics: true),
                    ),
                  ),
                ),
              ),
            ),
            ZubiaNavItem(
              icon: Icons.favorite_outline,
              label: 'Saved',
              active: false,
              onTap: () => context.go('/saved'),
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
