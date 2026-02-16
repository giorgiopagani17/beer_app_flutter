import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userNameKey = 'user_name';

  static StorageService? _instance;
  static SharedPreferences? _preferences;

  static Future<StorageService> getInstance() async {
    _instance ??= StorageService._();
    _preferences ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  StorageService._();

  // Token methods
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userName,
  }) async {
    await _preferences!.setString(_accessTokenKey, accessToken);
    await _preferences!.setString(_refreshTokenKey, refreshToken);
    await _preferences!.setString(_userNameKey, userName);
  }
  
  Future<void> updateAccessToken(String accessToken) async {
    await _preferences!.setString(_accessTokenKey, accessToken);
  }

  String? getAccessToken() {
    return _preferences!.getString(_accessTokenKey);
  }

  String? getRefreshToken() {
    return _preferences!.getString(_refreshTokenKey);
  }

  String? getUserName() {
    return _preferences!.getString(_userNameKey);
  }

  bool isLoggedIn() {
    final accessToken = getAccessToken();
    final refreshToken = getRefreshToken();
    return accessToken != null && refreshToken != null;
  }

  Future<void> clearTokens() async {
    await _preferences!.remove(_accessTokenKey);
    await _preferences!.remove(_refreshTokenKey);
    await _preferences!.remove(_userNameKey);
  }
}