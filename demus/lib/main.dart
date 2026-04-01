import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/music_provider.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation.dart';

// Clé globale pour les SnackBars
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Supabase
  await SupabaseService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider()),
      ],
      child: MaterialApp(
        title: 'Nono Music',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0A0A),
          primaryColor: const Color(0xFFFF2D55),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFF2D55),
            secondary: Color(0xFF30D158),
          ),
          fontFamily: 'SF Pro',
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Essayer de se connecter silencieusement
    await _authService.signInSilently();
    
    // Charger les données depuis Supabase si connecté
    if (_authService.isAuthenticated) {
      await context.read<MusicProvider>().loadFromSupabase();
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFFF2D55)),
              SizedBox(height: 16),
              Text('Chargement...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return StreamBuilder(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        final isAuth = _authService.isAuthenticated;
        
        if (isAuth) {
          return const MainNavigation();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}
