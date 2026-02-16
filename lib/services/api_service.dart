import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application/services/auth_service.dart';
import 'storage_service.dart';

class ApiService {
  static ApiService? _instance;
  static Dio? _dio;
  late StorageService _storageService;

  static Future<ApiService> getInstance() async {
    if (_instance == null) {
      _instance = ApiService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  ApiService._();

  Future<void> _initialize() async {
    _storageService = await StorageService.getInstance();

    _dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:4000',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Interceptor per aggiungere automaticamente il token
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _storageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          debugPrint('API Request: ${options.method} ${options.path}');
          debugPrint('Request Data: ${options.data}');

          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
            'API Response: ${response.statusCode} ${response.requestOptions.path}',
          );
          debugPrint('Response Data: ${response.data}');
          handler.next(response);
        },
        onError: (error, handler) async {
          debugPrint(
            'API Error: ${error.response?.statusCode} ${error.requestOptions.path}',
          );
          debugPrint('Error Message: ${error.message}');

          // Auto-refresh token se 401
          if (error.response?.statusCode == 401) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Riprova la richiesta originale
              final options = error.requestOptions;
              final token = _storageService.getAccessToken();
              options.headers['Authorization'] = 'Bearer $token';

              try {
                final response = await _dio!.fetch(options);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = _storageService.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _dio!.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 201) {
        final data = response.data;
        final newAccessToken = data['access_token'];

        if (newAccessToken != null && newAccessToken is String) {
          await _storageService.updateAccessToken(newAccessToken);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      final auth = await AuthService.getInstance();
      await auth.logout();
    }
    return false;
  }

  // Auth methods
  Future<ApiResponse<AuthResponse>> login({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('ApiService: Making login request for: $email');

      final response = await _dio!.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      debugPrint('ApiService: Login response status: ${response.statusCode}');
      debugPrint('ApiService: Login response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final authData = AuthResponse.fromJson(response.data);
          debugPrint('ApiService: Successfully parsed AuthResponse');
          debugPrint('ApiService: User name: ${authData.name}');
          return ApiResponse.success(authData);
        } catch (e) {
          debugPrint('ApiService: Error parsing AuthResponse: $e');
          return ApiResponse.error('Errore nel parsing della risposta');
        }
      }

      return ApiResponse.error('Login fallito: ${response.statusMessage}');
    } on DioException catch (e) {
      debugPrint('ApiService: DioException during login: ${e.message}');
      return _handleDioException(e);
    } catch (e) {
      debugPrint('ApiService: Generic error during login: $e');
      return ApiResponse.error('Errore imprevisto: $e');
    }
  }

  Future<ApiResponse<AuthResponse>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('ApiService: Making register request for: $email');

      final response = await _dio!.post(
        '/auth/register',
        data: {'name': name, 'email': email, 'password': password},
      );

      debugPrint(
        'ApiService: Register response status: ${response.statusCode}',
      );
      debugPrint('ApiService: Register response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final authData = AuthResponse.fromJson(response.data);
          debugPrint('ApiService: Successfully parsed AuthResponse');
          debugPrint('ApiService: User name: ${authData.name}');
          return ApiResponse.success(authData);
        } catch (e) {
          debugPrint('ApiService: Error parsing AuthResponse: $e');
          return ApiResponse.error('Errore nel parsing della risposta');
        }
      }

      return ApiResponse.error(
        'Registrazione fallita: ${response.statusMessage}',
      );
    } on DioException catch (e) {
      debugPrint('ApiService: DioException during register: ${e.message}');
      return _handleDioException(e);
    } catch (e) {
      debugPrint('ApiService: Generic error during register: $e');
      return ApiResponse.error('Errore imprevisto: $e');
    }
  }

  // Beer methods
  Future<ApiResponse<List<dynamic>>> getBeers({
    int page = 1,
    int limit = 5,
    String? query,
    double? minAlcohol,
    double? maxAlcohol,
    int? colorId,
    int? countryId,
    bool? isFavorite,
  }) async {
    try {
      final params = <String, dynamic>{'page': page, 'limit': limit};

      if (query != null && query.isNotEmpty) params['query'] = query;
      if (minAlcohol != null) params['minAlcohol'] = minAlcohol;
      if (maxAlcohol != null) params['maxAlcohol'] = maxAlcohol;
      if (colorId != null) params['colorId'] = colorId;
      if (countryId != null) params['countryId'] = countryId;
      if (isFavorite != null) params['isFavorite'] = isFavorite;

      // Determina endpoint
      String endpoint = '/beers/search';
      if ((query != null && query.isNotEmpty) ||
          colorId != null ||
          countryId != null ||
          minAlcohol != null ||
          maxAlcohol != null) {
        endpoint = '/beers/search';
      }

      final response = await _dio!.get(endpoint, queryParameters: params);

      if (response.statusCode == 200) {
        final data = response.data;
        // Estrai la lista dalla chiave 'data'
        if (data is Map<String, dynamic> && data['data'] is List) {
          return ApiResponse.success(data['data'] as List<dynamic>);
        } else {
          return ApiResponse.error('Formato risposta non valido');
        }
      }

      return ApiResponse.error('Errore nel caricamento delle birre');
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      return ApiResponse.error('Errore imprevisto: $e');
    }
  }

  Future<ApiResponse<List<dynamic>>> getBeerColors() async {
    try {
      final response = await _dio!.get('/beer-colors');
      if (response.statusCode == 200) {
        return ApiResponse.success(response.data);
      }
      return ApiResponse.error('Errore nel caricamento dei colori');
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      return ApiResponse.error('Errore imprevisto: $e');
    }
  }

  Future<ApiResponse<List<dynamic>>> getCountries() async {
    try {
      final response = await _dio!.get('/countries');
      if (response.statusCode == 200) {
        return ApiResponse.success(response.data);
      }
      return ApiResponse.error('Errore nel caricamento dei paesi');
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      return ApiResponse.error('Errore imprevisto: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getAlcoholRange() async {
    try {
      final response = await _dio!.get('/alcohol-content/range');
      if (response.statusCode == 200) {
        return ApiResponse.success(response.data);
      }
      return ApiResponse.error('Errore nel caricamento del range alcolico');
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      return ApiResponse.error('Errore imprevisto: $e');
    }
  }

  Future<ApiResponse<void>> addToFavorite(int beerId) async {
    try {
      final response = await _dio!.post('/favorites/$beerId');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.success(null);
      }
      return ApiResponse.error('Errore nell\'aggiunta ai preferiti');
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      return ApiResponse.error('Errore imprevisto: $e');
    }
  }

  Future<ApiResponse<void>> deleteFavorite(int beerId) async {
    try {
      final response = await _dio!.delete('/favorites/$beerId');
      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(null);
      }
      return ApiResponse.error('Errore nella rimozione dai preferiti');
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      return ApiResponse.error('Errore imprevisto: $e');
    }
  }

  Future<ApiResponse<List<dynamic>>> getRecommendedBeers({
    int limit = 5,
  }) async {
    try {
      final response = await _dio!.get(
        '/favorites/recommended',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['data'] is List) {
          return ApiResponse.success(data['data'] as List<dynamic>);
        } else {
          return ApiResponse.error('Formato risposta non valido');
        }
      }
      return ApiResponse.error(
        'Errore nel caricamento delle birre consigliate',
      );
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      return ApiResponse.error('Errore imprevisto: $e');
    }
  }

  Future<ApiResponse<void>> postScore(int score) async {
    try {
      final response = await _dio!.post(
        '/scores',
        data: {'score': score},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.success(null);
      }
      return ApiResponse.error('Errore nell\'invio del punteggio');
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      return ApiResponse.error('Errore imprevisto: $e');
    }
  }

  Future<ApiResponse<List<dynamic>>> getScores({int page = 1, int limit = 10}) async {
    try {
      final response = await _dio!.get(
        '/scores',
        queryParameters: {'page': page, 'limit': limit},
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['data'] is List) {
          return ApiResponse.success(data['data'] as List<dynamic>);
        } else if (data is List) {
          return ApiResponse.success(data);
        } else {
          return ApiResponse.error('Formato risposta non valido');
        }
      }
      return ApiResponse.error('Errore nel caricamento dei punteggi');
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      return ApiResponse.error('Errore imprevisto: $e');
    }
  }

  ApiResponse<T> _handleDioException<T>(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return ApiResponse.error('Timeout di connessione');
      case DioExceptionType.receiveTimeout:
        return ApiResponse.error('Timeout di ricezione dati');
      case DioExceptionType.connectionError:
        return ApiResponse.error('Errore di connessione al server');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final errorMessage =
            e.response?.data?['message'] ??
            e.response?.data?['error'] ??
            'Errore del server';

        switch (statusCode) {
          case 400:
            return ApiResponse.error('Richiesta non valida: $errorMessage');
          case 401:
            return ApiResponse.error('Accesso Scaduto');
          case 403:
            return ApiResponse.error('Accesso negato');
          case 404:
            return ApiResponse.error('Risorsa non trovata');
          case 409:
            return ApiResponse.error('Conflitto - risorsa già esistente');
          case 500:
            return ApiResponse.error('Errore interno del server');
          default:
            return ApiResponse.error('Errore del server: $errorMessage');
        }
      default:
        return ApiResponse.error('Errore di rete: ${e.message}');
    }
  }
}

// Modelli di risposta
class ApiResponse<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResponse.success(this.data) : error = null, isSuccess = true;
  ApiResponse.error(this.error) : data = null, isSuccess = false;
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String name;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.name,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'name': name,
    };
  }
}
