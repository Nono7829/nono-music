import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'services/audio_service_initializer.dart';
import 'services/music_provider.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await SupabaseService.initialize();

  // ── Critical: audio service initialized ONCE, before runApp ──────────────
  await AudioServiceInitializer.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MusicProvider>(create: (_) => MusicProvider()),
      ],
      child: const NonoMusicApp(),
    ),
  );
}

class NonoMusicApp extends StatelessWidget {
  const NonoMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nono Music',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.dark,
      home: const _AuthWrapper(),
    );
  }
}

class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper();

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
  final _auth = AuthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _auth.signInSilently();
    if (!mounted) return;
    if (_auth.isAuthenticated) {
      await context.read<MusicProvider>().loadFromSupabase();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF000000),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF375F),
            strokeWidth: 2,
          ),
        ),
      );
    }

    return StreamBuilder(
      stream: _auth.authStateChanges,
      builder: (_, __) => _auth.isAuthenticated
          ? const MainNavigation()
          : const AuthScreen(),
    );
  }
}