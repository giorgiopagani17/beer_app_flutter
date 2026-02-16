import 'package:flutter/material.dart';
import 'routes/routes.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'pages/login_page.dart';
import 'pages/main_navigation_page.dart'; // CORREZIONE: import corretto

// GlobalKey per il navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inizializza i servizi
  await StorageService.getInstance();
  await AuthService.getInstance();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beer Catalog',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  AuthService? _authService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      _authService = await AuthService.getInstance();
      _authService!.addListener(_onAuthStateChanged);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      
      debugPrint('AuthWrapper: Initialized with isLoggedIn: ${_authService!.isLoggedIn}');
    } catch (e) {
      debugPrint('Error initializing auth: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  void _onAuthStateChanged() {
    debugPrint('AuthWrapper: Auth state changed! isLoggedIn: ${_authService?.isLoggedIn}');
    if (mounted) {
      setState(() {
        // Il rebuild si occuperà di mostrare la pagina corretta
      });
    }
  }

  @override
  void dispose() {
    _authService?.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _authService == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sports_bar,
                size: 80,
                color: Colors.deepPurple,
              ),
              SizedBox(height: 24),
              Text(
                'Beer Catalog',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              ),
              SizedBox(height: 16),
              Text('Inizializzazione...'),
            ],
          ),
        ),
      );
    }

    debugPrint('AuthWrapper: Building with isLoggedIn: ${_authService!.isLoggedIn}');

    // CORREZIONE: Usa MainNavigationPage invece di MainNavigation
    if (_authService!.isLoggedIn) {
      debugPrint('AuthWrapper: Showing main navigation');
      return const MainNavigationPage();
    } else {
      debugPrint('AuthWrapper: Showing login page');
      return const LoginPage();
    }
  }
}