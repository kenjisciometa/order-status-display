import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

/// Platform-specific Secure Storage Service for OSD
///
/// This service provides secure token storage across different platforms:
/// - iOS: Uses Keychain via FlutterSecureStorage
/// - Android: Uses EncryptedSharedPreferences via FlutterSecureStorage
/// - Linux/Raspberry Pi: Uses Hive encrypted box (no keyring dependency)
/// - macOS: Uses Keychain via FlutterSecureStorage
/// - Windows: Uses Windows Credential Manager via FlutterSecureStorage
///
/// For Linux environments without keyring services (common on Raspberry Pi),
/// this service falls back to Hive with AES-256 encryption.
class SecureStorageService {
  static const String _hiveBoxName = 'osd_secure_storage';
  static const String _encryptionKeyStorageKey = 'osd_hive_encryption_key';

  // Singleton instance
  static SecureStorageService? _instance;
  static SecureStorageService get instance {
    _instance ??= SecureStorageService._internal();
    return _instance!;
  }

  SecureStorageService._internal();

  // Platform-specific storage backends
  FlutterSecureStorage? _secureStorage;
  Box<String>? _hiveBox;
  bool _initialized = false;
  bool _useHiveFallback = false;

  /// Initialize the storage service
  Future<void> initialize() async {
    if (_initialized) return;

    if (_shouldUseHiveFallback()) {
      await _initializeHive();
      _useHiveFallback = true;
    } else {
      _initializeSecureStorage();
      _useHiveFallback = false;
    }

    _initialized = true;

    if (kDebugMode) {
      debugPrint(
          '🔐 [SecureStorage] Initialized with ${_useHiveFallback ? "Hive (Linux fallback)" : "FlutterSecureStorage"}');
    }
  }

  /// Determine if we should use Hive fallback (for Linux without keyring)
  bool _shouldUseHiveFallback() {
    // Use Hive for Linux (including Raspberry Pi)
    // FlutterSecureStorage on Linux requires libsecret and a keyring daemon
    // which may not be available on minimal Raspberry Pi installations
    if (Platform.isLinux) {
      if (kDebugMode) {
        debugPrint(
            '🔐 [SecureStorage] Linux detected, using Hive encrypted storage');
      }
      return true;
    }
    return false;
  }

  /// Initialize FlutterSecureStorage for iOS/Android/macOS/Windows
  void _initializeSecureStorage() {
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
  }

  /// Initialize Hive with encryption for Linux
  Future<void> _initializeHive() async {
    await Hive.initFlutter();

    // Get or generate encryption key
    final encryptionKey = await _getOrCreateEncryptionKey();

    // Open encrypted box
    _hiveBox = await Hive.openBox<String>(
      _hiveBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }

  /// Get or create a device-specific encryption key for Hive
  /// The key is derived from device-specific information to provide some protection
  Future<Uint8List> _getOrCreateEncryptionKey() async {
    // Try to read existing key from a hidden file
    final appDir = await getApplicationSupportDirectory();
    final keyFile = File('${appDir.path}/.osd_key');

    if (await keyFile.exists()) {
      final keyBytes = await keyFile.readAsBytes();
      if (keyBytes.length == 32) {
        return keyBytes;
      }
    }

    // Generate new key based on device info and random data
    // This provides better security than a hardcoded key
    final deviceSeed = await _getDeviceSeed();
    final randomBytes = List<int>.generate(16, (i) => DateTime.now().microsecond % 256);

    final combined = [...deviceSeed, ...randomBytes];
    final hash = sha256.convert(combined);
    final keyBytes = Uint8List.fromList(hash.bytes);

    // Save key to hidden file with restricted permissions
    await keyFile.writeAsBytes(keyBytes);

    // On Linux, try to set file permissions to owner-only
    if (Platform.isLinux) {
      try {
        await Process.run('chmod', ['600', keyFile.path]);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [SecureStorage] Could not set key file permissions: $e');
        }
      }
    }

    return keyBytes;
  }

  /// Generate a device-specific seed for key derivation
  Future<List<int>> _getDeviceSeed() async {
    final seedParts = <String>[];

    // Add platform info
    seedParts.add(Platform.operatingSystem);
    seedParts.add(Platform.operatingSystemVersion);

    // Add hostname if available
    try {
      final hostname = Platform.localHostname;
      seedParts.add(hostname);
    } catch (_) {}

    // Add user home directory (unique per user)
    final home = Platform.environment['HOME'] ?? '';
    seedParts.add(home);

    // Combine and hash
    final seedString = seedParts.join('|');
    return utf8.encode(seedString);
  }

  /// Read a value from secure storage
  Future<String?> read({required String key}) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      if (_useHiveFallback) {
        return _hiveBox?.get(key);
      } else {
        return await _secureStorage?.read(key: key);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SecureStorage] Error reading key "$key": $e');
      }
      return null;
    }
  }

  /// Write a value to secure storage
  Future<void> write({required String key, required String value}) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      if (_useHiveFallback) {
        await _hiveBox?.put(key, value);
      } else {
        await _secureStorage?.write(key: key, value: value);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SecureStorage] Error writing key "$key": $e');
      }
      rethrow;
    }
  }

  /// Delete a value from secure storage
  Future<void> delete({required String key}) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      if (_useHiveFallback) {
        await _hiveBox?.delete(key);
      } else {
        await _secureStorage?.delete(key: key);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SecureStorage] Error deleting key "$key": $e');
      }
      rethrow;
    }
  }

  /// Delete all values from secure storage
  Future<void> deleteAll() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      if (_useHiveFallback) {
        await _hiveBox?.clear();
      } else {
        await _secureStorage?.deleteAll();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SecureStorage] Error deleting all: $e');
      }
      rethrow;
    }
  }

  /// Check if a key exists in secure storage
  Future<bool> containsKey({required String key}) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      if (_useHiveFallback) {
        return _hiveBox?.containsKey(key) ?? false;
      } else {
        final value = await _secureStorage?.read(key: key);
        return value != null;
      }
    } catch (e) {
      return false;
    }
  }

  /// Get the storage type being used (for debugging)
  String get storageType {
    if (!_initialized) return 'not initialized';
    return _useHiveFallback ? 'Hive (encrypted)' : 'FlutterSecureStorage';
  }

  /// Check if using Hive fallback
  bool get isUsingHiveFallback => _useHiveFallback;
}
