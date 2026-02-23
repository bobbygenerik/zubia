import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/zubia_logo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final state = context.read<AppState>();
    await state.loadLanguages();
    await state.loadIdentity();
    if (state.userId != null && mounted) {
      await state.loadThreads();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) return;
    if (!_isLogin && name.isEmpty) return;

    final state = context.read<AppState>();
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    String? error;
    if (_isLogin) {
      error = await state.signIn(email, password);
    } else {
      error = await state.registerAndSaveIdentity(
        email,
        password,
        name,
        state.userLanguage.isNotEmpty ? state.userLanguage : 'en',
      );
    }

    if (error == null) {
      await state.loadThreads();
      if (mounted) {
        setState(() => _isLoading = false);
        if (state.userId != null && context.mounted) {
          context.go('/home');
        }
      }
    } else {
      setState(() {
        _errorMsg = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZubiaColors.magenta),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, state, _) {
            if (state.userId == null) {
              return _buildIdentityView(state);
            }
            return _buildThreadsView(state);
          },
        ),
      ),
    );
  }

  Widget _buildIdentityView(AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          Text(
            _isLogin ? 'Welcome Back' : 'Create Your Profile',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _isLogin
                ? 'Sign in to continue'
                : 'Enter your details to get started.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: ZubiaColors.textSecondary),
          ),
          const SizedBox(height: 32),
          if (_errorMsg != null) ...[
            Text(
              _errorMsg!,
              style: const TextStyle(color: ZubiaColors.danger),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Email',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Password',
              prefixIcon: Icon(Icons.lock_outline, size: 20),
            ),
          ),
          if (!_isLogin) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Your name',
                prefixIcon: Icon(Icons.person_outline, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: state.userLanguage.isNotEmpty
                  ? state.userLanguage
                  : 'en',
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
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed:
                (_emailController.text.isNotEmpty &&
                    _passwordController.text.isNotEmpty &&
                    (_isLogin || _nameController.text.isNotEmpty))
                ? _submitAuth
                : null,
            child: Text(_isLogin ? 'Sign In' : 'Sign Up'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() {
              _isLogin = !_isLogin;
              _errorMsg = null;
            }),
            child: Text(
              _isLogin
                  ? 'Need an account? Sign up'
                  : 'Already have an account? Sign in',
              style: const TextStyle(color: ZubiaColors.magenta),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildThreadsView(AppState state) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chats',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Logged in as ${state.userName}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: ZubiaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => context.go('/settings'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (state.threads.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No messages yet.\nStart a new chat below!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ZubiaColors.textMuted),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: state.threads.length,
                      separatorBuilder: (context, index) => const Divider(
                        color: ZubiaColors.glassBorder,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final thread = state.threads[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: ZubiaColors.magenta.withValues(
                              alpha: 0.1,
                            ),
                            child: Text(
                              state.getFlagEmoji(
                                thread['otherUserLanguage'] ?? 'en',
                              ),
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          title: Text(
                            thread['otherUserName'] ?? 'Unknown User',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Tap to join chat',
                            style: TextStyle(
                              color: ZubiaColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () {
                            state.joinThread(
                              thread['id'],
                              thread['otherUserName'],
                            );
                            context.go('/chat');
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/new_chat'),
              icon: const Icon(Icons.add_comment),
              label: const Text('Start New Chat'),
            ),
          ),
        ),
        const _BottomNav(currentIndex: 0),
      ],
    );
  }
}

// ─── Shared Widgets ──────────────────────────────

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
            _NavItem(
              icon: Icons.chat_bubble_outline,
              label: 'Chats',
              active: currentIndex == 0,
              onTap: () => context.go('/home'),
            ),
            _NavItem(
              icon: Icons.history,
              label: 'History',
              active: currentIndex == 1,
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
            _NavItem(
              icon: Icons.favorite_outline,
              label: 'Saved',
              active: currentIndex == 2,
              onTap: () => context.go('/saved'),
            ),
            _NavItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              active: currentIndex == 3,
              onTap: () => context.go('/settings'),
            ),
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
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: active ? ZubiaColors.magenta : ZubiaColors.textMuted,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: active ? ZubiaColors.magenta : ZubiaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
