import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../widgets/nav_item.dart';
import '../widgets/zubia_logo.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    onPressed: () => context.go('/lobby'),
                  ),
                  const SizedBox(width: 24, height: 24, child: ZubiaLogo()),
                  const SizedBox(width: 10),
                  const Text(
                    'Zubia',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search, size: 22),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Search coming soon!')),
                      );
                    },
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
                children: [
                  _DateDivider(label: 'Today'),
                  _HistoryCard(
                    fromLang: 'EN',
                    toLang: 'ES',
                    time: '10:42 AM',
                    original: 'Where is the nearest subway station?',
                    translated: '¿Dónde está la estación de metro más cercana?',
                    isVoice: true,
                  ),
                  _HistoryCard(
                    fromLang: 'EN',
                    toLang: 'FR',
                    time: '09:15 AM',
                    original: 'I would like to order two coffees, please.',
                    translated:
                        'Je voudrais commander deux cafés, s\'il vous plaît.',
                    isVoice: true,
                  ),
                  _DateDivider(label: 'Yesterday'),
                  _HistoryCard(
                    fromLang: 'JP',
                    toLang: 'EN',
                    time: '06:30 PM',
                    original: 'ありがとうございます',
                    translated: 'Thank you very much',
                    isVoice: false,
                  ),
                  _HistoryCard(
                    fromLang: 'EN',
                    toLang: 'IT',
                    time: '02:15 PM',
                    original: 'Can you recommend a good restaurant nearby?',
                    translated:
                        'Puoi consigliarmi un buon ristorante qui vicino?',
                    isVoice: true,
                  ),
                ],
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

  const _HistoryCard({
    required this.fromLang,
    required this.toLang,
    required this.time,
    required this.original,
    required this.translated,
    required this.isVoice,
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
                Container(
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
              onTap: () => context.go('/lobby'),
            ),
            ZubiaNavItem(
              icon: Icons.history,
              label: 'History',
              active: true,
              onTap: () {},
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
              icon: Icons.favorite_outline,
              label: 'Saved',
              active: false,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved items coming soon!')),
                );
              },
            ),
            ZubiaNavItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              active: false,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
