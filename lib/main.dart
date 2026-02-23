import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'theme.dart';
import 'providers/app_state.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/new_chat_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/saved_chats_screen.dart';

// ── Server Configuration ─────────────────────────
// Change this to your VPS IP/domain
const String kServerUrl = 'http://15.204.95.57';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
  redirect: (context, state) {
    final appState = Provider.of<AppState>(context, listen: false);
    final isLoggedIn = appState.auth.currentUser != null;
    final isOnboarding = state.matchedLocation == '/onboarding';

    if (isLoggedIn && isOnboarding) {
      return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/new_chat',
      builder: (context, state) => const NewChatScreen(),
    ),
    GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/saved',
      builder: (context, state) => const SavedChatsScreen(),
    ),
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
