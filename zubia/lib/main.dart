import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'theme.dart';
import 'providers/app_state.dart';
import 'screens/onboarding_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/history_screen.dart';

// ── Server Configuration ─────────────────────────
// Change this to your VPS IP/domain
const String kServerUrl = 'http://15.204.95.57';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: ZubiaColors.charcoalDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ZubiaApp());
}

final _router = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/lobby', builder: (context, state) => const LobbyScreen()),
    GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
    GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
  ],
);

class ZubiaApp extends StatelessWidget {
  const ZubiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(serverUrl: kServerUrl),
      child: MaterialApp.router(
        title: 'Zubia',
        debugShowCheckedModeBanner: false,
        theme: zubiaTheme(),
        routerConfig: _router,
      ),
    );
  }
}
