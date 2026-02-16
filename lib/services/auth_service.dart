import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'storage_service.dart';
import '../main.dart';

class AuthService extends ChangeNotifier {
  static AuthService? _instance;
  late ApiService _apiService;
  late StorageService _storageService;
  
  bool _isLoggedIn = false;
  String? _userName;
  bool _isLoading = false;

  bool get isLoggedIn => _isLoggedIn;
  String? get userName => _userName;
  bool get isLoading => _isLoading;

  static Future<AuthService> getInstance() async {
    if (_instance == null) {
      _instance = AuthService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  AuthService._();

  Future<void> _initialize() async {
    try {
      _apiService = await ApiService.getInstance();
      _storageService = await StorageService.getInstance();
      
      // Controlla se l'utente è già loggato
      _isLoggedIn = _storageService.isLoggedIn();
      _userName = _storageService.getUserName();
      
      debugPrint('AuthService initialized: isLoggedIn=$_isLoggedIn, userName=$_userName');
      
      // Verifica se i token sono validi
      if (_isLoggedIn && _userName != null) {
        final accessToken = _storageService.getAccessToken();
        final refreshToken = _storageService.getRefreshToken();
        
        debugPrint('AuthService: Found tokens in storage');
        debugPrint('AuthService: Access token present: ${accessToken != null}');
        debugPrint('AuthService: Refresh token present: ${refreshToken != null}');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('AuthService initialization error: $e');
      _isLoggedIn = false;
      _userName = null;
      notifyListeners();
    }
  }

  Future<String?> login(String email, String password) async {
    _setLoading(true);

    try {
      debugPrint('AuthService: Attempting login for: $email');
      final response = await _apiService.login(email: email, password: password);
      
      debugPrint('AuthService: API Response - Success: ${response.isSuccess}');
      debugPrint('AuthService: API Response - Error: ${response.error}');
      debugPrint('AuthService: API Response - Data: ${response.data != null ? "Present" : "Null"}');
      
      if (response.isSuccess && response.data != null) {
        debugPrint('AuthService: Saving tokens...');
        debugPrint('AuthService: Access token: ${response.data!.accessToken.substring(0, 50)}...');
        debugPrint('AuthService: Refresh token: ${response.data!.refreshToken.substring(0, 50)}...');
        debugPrint('AuthService: User name: ${response.data!.name}');
        
        // Salva i token nello storage
        await _storageService.saveTokens(
          accessToken: response.data!.accessToken,
          refreshToken: response.data!.refreshToken,
          userName: response.data!.name,
        );
        
        // Verifica che i token siano stati salvati
        final savedAccessToken = _storageService.getAccessToken();
        final savedRefreshToken = _storageService.getRefreshToken();
        final savedUserName = _storageService.getUserName();
        
        debugPrint('AuthService: Tokens verification:');
        debugPrint('AuthService: Saved access token: ${savedAccessToken != null}');
        debugPrint('AuthService: Saved refresh token: ${savedRefreshToken != null}');
        debugPrint('AuthService: Saved user name: $savedUserName');
        
        _isLoggedIn = true;
        _userName = response.data!.name;
        
        debugPrint('AuthService: Login successful: $_userName');
        debugPrint('AuthService: isLoggedIn set to: $_isLoggedIn');
        
        notifyListeners();
        return null; // Success
      } else {
        debugPrint('AuthService: Login failed: ${response.error ?? "Unknown error"}');
        return response.error ?? 'Login fallito';
      }
    } catch (e) {
      debugPrint('AuthService: Login error (exception): $e');
      return 'Errore durante il login: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> register(String name, String email, String password) async {
    _setLoading(true);

    try {
      debugPrint('AuthService: Attempting registration for: $email');
      final response = await _apiService.register(
        name: name,
        email: email,
        password: password,
      );
      
      debugPrint('AuthService: API Response - Success: ${response.isSuccess}');
      debugPrint('AuthService: API Response - Error: ${response.error}');
      debugPrint('AuthService: API Response - Data: ${response.data != null ? "Present" : "Null"}');
      
      if (response.isSuccess && response.data != null) {
        debugPrint('AuthService: Saving tokens...');
        debugPrint('AuthService: Access token: ${response.data!.accessToken.substring(0, 50)}...');
        debugPrint('AuthService: Refresh token: ${response.data!.refreshToken.substring(0, 50)}...');
        debugPrint('AuthService: User name: ${response.data!.name}');
        
        // Salva i token nello storage
        await _storageService.saveTokens(
          accessToken: response.data!.accessToken,
          refreshToken: response.data!.refreshToken,
          userName: response.data!.name,
        );
        
        // Verifica che i token siano stati salvati
        final savedAccessToken = _storageService.getAccessToken();
        final savedRefreshToken = _storageService.getRefreshToken();
        final savedUserName = _storageService.getUserName();
        
        debugPrint('AuthService: Tokens verification:');
        debugPrint('AuthService: Saved access token: ${savedAccessToken != null}');
        debugPrint('AuthService: Saved refresh token: ${savedRefreshToken != null}');
        debugPrint('AuthService: Saved user name: $savedUserName');
        
        _isLoggedIn = true;
        _userName = response.data!.name;
        
        debugPrint('AuthService: Registration successful: $_userName');
        debugPrint('AuthService: isLoggedIn set to: $_isLoggedIn');
        
        notifyListeners();
        return null; // Success
      } else {
        debugPrint('AuthService: Registration failed: ${response.error ?? "Unknown error"}');
        return response.error ?? 'Registrazione fallita';
      }
    } catch (e) {
      debugPrint('AuthService: Registration error (exception): $e');
      return 'Errore durante la registrazione: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);

    try {
      debugPrint('AuthService: Logging out...');
      
      // Cancella i token locali (SENZA chiamata API)
      await _storageService.clearTokens();
      
      _isLoggedIn = false;
      _userName = null;
      
      debugPrint('AuthService: Logout completed');
      debugPrint('AuthService: isLoggedIn set to: $_isLoggedIn');
      debugPrint('AuthService: userName set to: $_userName');
      
      // NAVIGAZIONE FORZATA AL LOGIN
      debugPrint('AuthService: Forcing navigation to login...');
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
      
    } catch (e) {
      debugPrint('AuthService: Logout error: $e');
      // Anche in caso di errore, resetta tutto
      _isLoggedIn = false;
      _userName = null;
      
      // NAVIGAZIONE FORZATA ANCHE IN CASO DI ERRORE
      debugPrint('AuthService: Forcing navigation to login (error case)...');
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Metodo per forzare il refresh dello stato di login
  Future<void> refreshAuthState() async {
    _isLoggedIn = _storageService.isLoggedIn();
    _userName = _storageService.getUserName();
    
    debugPrint('AuthService: Auth state refreshed');
    debugPrint('AuthService: isLoggedIn: $_isLoggedIn');
    debugPrint('AuthService: userName: $_userName');
    
    notifyListeners();
  }
}