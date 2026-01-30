import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/api_endpoints.dart';

/// API response wrapper
class ApiResponse<T> {
  final T? data;
  final String? message;
  final bool success;
  final int? statusCode;
  final Map<String, dynamic>? meta;

  const ApiResponse({
    this.data,
    this.message,
    required this.success,
    this.statusCode,
    this.meta,
  });

  factory ApiResponse.success(T data, {String? message, int? statusCode}) {
    return ApiResponse<T>(
      data: data,
      message: message,
      success: true,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.error(String message,
      {int? statusCode, Map<String, dynamic>? meta}) {
    return ApiResponse<T>(
      message: message,
      success: false,
      statusCode: statusCode,
      meta: meta,
    );
  }
}

/// Secure API client service for the OSD Flutter app
///
/// This service handles all HTTP communication with the backend API,
/// including authentication, request/response processing, and error handling.
class ApiClientService {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _deviceIdKey = 'device_id';
  static const String _autoLoginKey = 'osd_auto_login_enabled';
  static const String _emailKey = 'stored_email';
  static const String _passwordKey = 'stored_password';

  late final Dio _dio;
  SharedPreferences? _prefs;
  String? _deviceId;

  /// Singleton instance
  static ApiClientService? _instance;
  static ApiClientService get instance {
    _instance ??= ApiClientService._internal();
    return _instance!;
  }

  ApiClientService._internal() {
    _initializeDio();
  }

  /// Get SharedPreferences instance (lazy initialization)
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: ApiHeaders.defaultHeaders,
    ));

    // Add interceptors
    _dio.interceptors.add(_AuthInterceptor(this));
    _dio.interceptors.add(_LoggingInterceptor());
    _dio.interceptors.add(_ErrorInterceptor());
  }

  /// Initialize the service
  Future<void> initialize() async {
    _deviceId = await _getOrCreateDeviceId();
    debugPrint('🔧 [OSD API CLIENT] Initialized with device ID: $_deviceId');
  }

  /// Get or create device ID
  Future<String> _getOrCreateDeviceId() async {
    final prefs = await _getPrefs();
    String? deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  /// Get device ID
  String? get deviceId => _deviceId;

  // ===================
  // Authentication Token Management
  // ===================

  /// Set authentication token
  Future<void> setAuthToken(String token, [String? refreshToken]) async {
    debugPrint(
        '💾 [OSD API CLIENT] Storing auth token - length: ${token.length}');
    final prefs = await _getPrefs();
    await prefs.setString(_tokenKey, token);
    if (refreshToken != null) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
  }

  /// Get authentication token
  Future<String?> getAuthToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(_tokenKey);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(_refreshTokenKey);
  }

  /// Clear authentication data
  Future<void> clearAuthData() async {
    final prefs = await _getPrefs();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  // ===================
  // Auto Login Credential Management
  // ===================

  /// Set auto-login enabled
  Future<void> setAutoLoginEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_autoLoginKey, enabled);
  }

  /// Check if auto-login is enabled
  Future<bool> isAutoLoginEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_autoLoginKey) ?? false;
  }

  /// Store credentials for auto-login
  Future<void> storeCredentials(String email, String password) async {
    final prefs = await _getPrefs();
    await prefs.setString(_emailKey, email);
    await prefs.setString(_passwordKey, password);
  }

  /// Get stored email
  Future<String?> getStoredEmail() async {
    final prefs = await _getPrefs();
    return prefs.getString(_emailKey);
  }

  /// Get stored password
  Future<String?> getStoredPassword() async {
    final prefs = await _getPrefs();
    return prefs.getString(_passwordKey);
  }

  /// Clear stored credentials
  Future<void> clearCredentials() async {
    final prefs = await _getPrefs();
    await prefs.remove(_emailKey);
    await prefs.remove(_passwordKey);
    await prefs.remove(_autoLoginKey);
  }

  /// Clear all stored data (logout)
  Future<void> clearAllData() async {
    await clearAuthData();
    await clearCredentials();
  }

  // ===================
  // Refresh Token
  // ===================

  /// Refresh authentication token
  Future<bool> refreshAuthToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        debugPrint('⚠️ [OSD API CLIENT] No refresh token available');
        return false;
      }

      final response = await _dio.post(
        ApiEndpoints.refreshToken,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final sessionData = data['session'] as Map<String, dynamic>?;
        final newToken = sessionData?['access_token'] as String?;
        final newRefreshToken = sessionData?['refresh_token'] as String?;

        if (newToken != null) {
          await setAuthToken(newToken, newRefreshToken);
          debugPrint('✅ [OSD API CLIENT] Successfully refreshed auth token');
          return true;
        }
      }

      debugPrint(
          '❌ [OSD API CLIENT] Token refresh failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ [OSD API CLIENT] Token refresh error: $e');
      return false;
    }
  }

  // ===================
  // HTTP Request Methods
  // ===================

  /// Generic GET request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      debugPrint('🌐 [OSD API CLIENT] GET Request to: $endpoint');

      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      debugPrint('❌ [OSD API CLIENT] GET Request failed for $endpoint: $e');
      return _handleError<T>(e);
    }
  }

  /// Generic POST request
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      debugPrint('🌐 [OSD API CLIENT] POST Request to: $endpoint');

      final response = await _dio.post(
        endpoint,
        data: data,
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      debugPrint('❌ [OSD API CLIENT] POST Request failed for $endpoint: $e');
      return _handleError<T>(e);
    }
  }

  /// Generic PUT request
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: data,
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return _handleError<T>(e);
    }
  }

  /// Generic PATCH request
  Future<ApiResponse<T>> patch<T>(
    String endpoint, {
    Map<String, dynamic>? data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.patch(
        endpoint,
        data: data,
      );

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return _handleError<T>(e);
    }
  }

  /// Generic DELETE request
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(
        endpoint,
        queryParameters: queryParameters,
      );
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return _handleError<T>(e);
    }
  }

  /// Handle successful response
  ApiResponse<T> _handleResponse<T>(
      Response response, T Function(dynamic)? fromJson) {
    final data = response.data;

    if (data is Map<String, dynamic>) {
      final message = data['message'] as String?;

      if (fromJson != null && data['data'] != null) {
        final parsedData = fromJson(data['data']);
        return ApiResponse.success(parsedData,
            message: message, statusCode: response.statusCode);
      } else {
        return ApiResponse.success(data as T,
            message: message, statusCode: response.statusCode);
      }
    } else {
      if (fromJson != null) {
        final parsedData = fromJson(data);
        return ApiResponse.success(parsedData, statusCode: response.statusCode);
      } else {
        return ApiResponse.success(data as T, statusCode: response.statusCode);
      }
    }
  }

  /// Handle error response
  ApiResponse<T> _handleError<T>(dynamic error) {
    if (error is DioException) {
      final response = error.response;

      debugPrint('❌ [OSD API CLIENT] Error occurred: ${error.message}');
      debugPrint('❌ [OSD API CLIENT] Status code: ${response?.statusCode}');

      if (response?.data is Map<String, dynamic>) {
        final data = response!.data as Map<String, dynamic>;
        final message = data['error'] as String? ??
            data['message'] as String? ??
            error.message ??
            'Unknown error occurred';

        // Handle rate limit errors (429)
        if (response.statusCode == 429) {
          final retryAfter = data['retryAfter'] as int? ?? 60;
          debugPrint(
              '🚨 [OSD API CLIENT] Rate limit exceeded. Retry after $retryAfter seconds');
          return ApiResponse.error(
            'Too many requests. Please try again in $retryAfter seconds.',
            statusCode: response.statusCode,
            meta: {
              ...data,
              'rate_limit_error': true,
              'retry_after': retryAfter
            },
          );
        }

        return ApiResponse.error(
          message,
          statusCode: response.statusCode,
          meta: data,
        );
      } else {
        return ApiResponse.error(
          error.message ?? 'Network error occurred',
          statusCode: response?.statusCode,
        );
      }
    }

    return ApiResponse.error('Unexpected error occurred: $error');
  }
}

/// Authentication interceptor
class _AuthInterceptor extends Interceptor {
  final ApiClientService _apiClient;

  _AuthInterceptor(this._apiClient);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // Add device ID header
    if (_apiClient._deviceId != null) {
      options.headers[ApiHeaders.xDeviceId] = _apiClient._deviceId;
    }

    // Add request ID for tracing
    final requestId = const Uuid().v4();
    options.headers[ApiHeaders.xRequestId] = requestId;

    // Add auth token if available
    final token = await _apiClient.getAuthToken();
    if (token != null) {
      options.headers[ApiHeaders.authorization] = 'Bearer $token';
      debugPrint(
          '✅ [OSD API CLIENT] Adding Bearer token to request: ${options.uri}');
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 Unauthorized - attempt token refresh
    if (err.response?.statusCode == 401) {
      try {
        debugPrint(
            '🔄 [OSD API CLIENT] Attempting auth recovery for 401 error');

        final refreshSuccess = await _apiClient.refreshAuthToken();
        if (refreshSuccess) {
          debugPrint(
              '✅ [OSD API CLIENT] Token refresh successful, retrying request');

          final newToken = await _apiClient.getAuthToken();
          if (newToken != null) {
            final retryOptions = err.requestOptions;
            retryOptions.headers[ApiHeaders.authorization] = 'Bearer $newToken';

            final retryResponse = await _apiClient._dio.fetch(retryOptions);
            handler.resolve(retryResponse);
            return;
          }
        }

        debugPrint(
            '❌ [OSD API CLIENT] All auth recovery strategies failed, clearing auth data');
        await _apiClient.clearAuthData();
      } catch (recoveryError) {
        debugPrint('❌ [OSD API CLIENT] Auth recovery error: $recoveryError');
        await _apiClient.clearAuthData();
      }
    }

    handler.next(err);
  }
}

/// Logging interceptor for debugging
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint(
        '📤 [OSD API CLIENT] Request: ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
        '📥 [OSD API CLIENT] Response: ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('❌ [OSD API CLIENT] Error: ${err.message}');
    handler.next(err);
  }
}

/// Error interceptor for consistent error handling
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        err = err.copyWith(
          message: 'Connection timeout. Please check your internet connection.',
        );
        break;
      case DioExceptionType.connectionError:
        err = err.copyWith(
          message:
              'Unable to connect to server. Please check your internet connection.',
        );
        break;
      case DioExceptionType.badResponse:
        // Keep original error message for bad responses
        break;
      case DioExceptionType.cancel:
        err = err.copyWith(
          message: 'Request was cancelled.',
        );
        break;
      default:
        err = err.copyWith(
          message: 'An unexpected error occurred.',
        );
    }

    handler.next(err);
  }
}
