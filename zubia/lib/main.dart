import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'theme.dart';
import 'config.dart';
import 'providers/app_state.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/new_chat_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/history_screen.dart';

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
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/new_chat', builder: (context, state) => const NewChatScreen()),
    GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
    GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
  ],
);

class ZubiaApp extends StatelessWidget {
  const ZubiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(serverUrl: Config.serverUrl),
      child: MaterialApp.router(
        title: 'Zubia',
        debugShowCheckedModeBanner: false,
        theme: zubiaTheme(),
        routerConfig: _router,
      ),
    );
  }
}
