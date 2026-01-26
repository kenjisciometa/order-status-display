/// Unified Environment Configuration Module
/// OSD (Order Status Display) Environment Configuration Management
///
/// Features:
/// - Environment detection (development/staging/production)
/// - Unified JWT configuration management
/// - Security validation
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SharedEnvironmentConfig {
  // Environment detection - read from .env file
  static String get environment =>
      dotenv.env['FLUTTER_ENV'] ??
      const String.fromEnvironment('FLUTTER_ENV', defaultValue: 'development');

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
  static bool get isStaging => environment == 'staging';

  // Log settings
  static bool get enableVerboseLogging {
    if (isDevelopment) return true;
    return const String.fromEnvironment('ENABLE_VERBOSE_LOGGING',
                defaultValue: 'false')
            .toLowerCase() ==
        'true';
  }

  // Common timeout settings
  static Duration get connectionTimeout {
    if (isProduction) return const Duration(seconds: 5);
    return const Duration(seconds: 10);
  }

  static int get maxReconnectAttempts {
    if (isProduction) return 3;
    return 5;
  }

  // JWT settings
  static Duration get jwtTokenExpiry {
    if (isProduction) return const Duration(hours: 8);
    return const Duration(hours: 24);
  }
}
