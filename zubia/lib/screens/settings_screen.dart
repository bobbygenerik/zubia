import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../widgets/nav_item.dart';
import '../widgets/zubia_logo.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    'Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ZubiaColors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Preferences',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Language and playback controls can be changed directly inside each chat.',
                          style: TextStyle(
                            color: ZubiaColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
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
              icon: Icons.settings,
              label: 'Settings',
              active: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
