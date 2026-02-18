# OSD プラットフォーム統一 要件定義書

## 概要

Order Status Display (OSD) アプリケーションにおいて、通常版（Android/iOS/Mac/Windows）とRaspberry Pi版を統合し、環境変数による切り替えで両方のプラットフォームに対応する。

### 目的

- コードベースの一本化による保守性向上
- 環境変数のみでプラットフォーム特性を切り替え可能に
- Raspberry Pi / Linux環境での安定動作を保証

### 対象ブランチ

| ブランチ | 説明 |
|---------|------|
| `origin/dev` | 通常版（現行） |
| `log/rasp_ver` | Raspberry Pi対応版 |

---

## 変更方針

**Raspberry Pi版 (`log/rasp_ver`) の実装をベースに統一する**

理由:
1. `shared_preferences` は全プラットフォームで動作する
2. `flutter_secure_storage` はLinux/Raspberry Piでkeyring依存の問題がある
3. `window_manager` による制御は条件分岐で無効化可能
4. 自動ログイン機能は環境変数が空なら動作しないため影響なし

---

## 差分分析

### 1. ストレージ

| 項目 | dev版 | rasp_ver版 | 統一後 |
|------|-------|-----------|--------|
| パッケージ | `flutter_secure_storage` | `shared_preferences` | `shared_preferences` |
| 暗号化 | OS標準のKeychain/Keystore | なし | なし（ローカル用途のため許容） |
| Linux対応 | △（keyring依存） | ◎ | ◎ |

**判断**: `shared_preferences` に統一。OSDはディスプレイ端末専用であり、機密情報の保存は限定的。

### 2. ウィンドウ管理

| 項目 | dev版 | rasp_ver版 | 統一後 |
|------|-------|-----------|--------|
| パッケージ | なし | `window_manager` | `window_manager` |
| フルスクリーン | なし | 自動 | 環境変数で制御 |
| 常に最前面 | なし | 有効 | 環境変数で制御 |

### 3. 自動ログイン

| 項目 | dev版 | rasp_ver版 | 統一後 |
|------|-------|-----------|--------|
| 機能 | なし | `.env`で設定 | `.env`で設定（空なら無効） |

### 4. WebSocket処理

| 項目 | dev版 | rasp_ver版 | 統一後 |
|------|-------|-----------|--------|
| エラーハンドリング | 基本 | 強化 | 強化版を採用 |
| フォールバック | なし | あり | あり |

### 5. Android設定

| 項目 | dev版 | rasp_ver版 | 統一後 |
|------|-------|-----------|--------|
| namespace | `com.sciometa.osd_app` | `com.sciometa.osd` | `com.sciometa.osd` |
| 署名設定 | debug | release対応 | release対応 |

---

## 実装詳細

### 1. 環境変数 (.env)

```env
# ===========================================
# OSD (Order Status Display) Environment Configuration
# ===========================================

# Environment: development, staging, or production
FLUTTER_ENV=development

# API Base URLs
API_BASE_URL=https://pos.sciometa.com
API_STAGING_BASE_URL=https://staging.sciometa.com
API_PROD_BASE_URL=https://pos.sciometa.com

# WebSocket URLs
WEBSOCKET_DEV_URL=ws://10.15.10.203:9002
WEBSOCKET_PRODUCTION_URL=wss://websocket.sciometa.com

# Development server settings (for local testing only)
WEBSOCKET_PORT=9000
DEV_SERVER_IP=localhost

# Logging
ENABLE_VERBOSE_LOGGING=false

# ===========================================
# Platform Mode Settings
# ===========================================

# Platform Mode: standard or kiosk
#   standard - Normal mode (manual login, no fullscreen enforcement)
#   kiosk    - Kiosk/Display mode (auto-login, fullscreen, always-on-top)
PLATFORM_MODE=standard

# ===========================================
# Kiosk Mode Settings (only applies when PLATFORM_MODE=kiosk)
# ===========================================

# Auto Login Credentials
# Leave empty to disable auto-login
AUTO_LOGIN_EMAIL=
AUTO_LOGIN_PASSWORD=

# Window Behavior (desktop platforms only)
KIOSK_FULLSCREEN=true
KIOSK_ALWAYS_ON_TOP=true
KIOSK_SKIP_TASKBAR=true
```

### 2. pubspec.yaml 変更

```yaml
dependencies:
  # ... existing dependencies ...

  # Local Storage (unified - works on all platforms including Linux)
  shared_preferences: ^2.2.2
  # Note: flutter_secure_storage removed to avoid keyring issues on Linux/Raspberry Pi

  # Window management (for desktop fullscreen/kiosk mode)
  window_manager: ^0.4.3
```

**削除するパッケージ:**
- `flutter_secure_storage: ^9.0.0`

**追加するパッケージ:**
- `window_manager: ^0.4.3`

### 3. main.dart 変更

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:window_manager/window_manager.dart';
// ... other imports

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set full screen (hide status bar and navigation bar) for mobile
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }

  // Initialize window manager for desktop platforms
  await _initializeWindowManager();

  runApp(const MyApp());
}

/// Initialize window manager for kiosk mode on desktop platforms
Future<void> _initializeWindowManager() async {
  // Only apply to desktop platforms
  if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
    return;
  }

  // Check if kiosk mode is enabled
  final platformMode = dotenv.env['PLATFORM_MODE'] ?? 'standard';
  if (platformMode != 'kiosk') {
    return;
  }

  // Get kiosk settings
  final fullscreen = dotenv.env['KIOSK_FULLSCREEN'] == 'true';
  final alwaysOnTop = dotenv.env['KIOSK_ALWAYS_ON_TOP'] == 'true';
  final skipTaskbar = dotenv.env['KIOSK_SKIP_TASKBAR'] == 'true';

  if (!fullscreen && !alwaysOnTop) {
    return;
  }

  await windowManager.ensureInitialized();

  final windowOptions = WindowOptions(
    title: 'Order Status Display',
    fullScreen: fullscreen,
    alwaysOnTop: alwaysOnTop,
    skipTaskbar: skipTaskbar,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (fullscreen) {
      await windowManager.setFullScreen(true);
    }
    if (alwaysOnTop) {
      await windowManager.setAlwaysOnTop(true);
    }
    await windowManager.show();
    await windowManager.focus();
  });
}
```

### 4. api_client_service.dart 変更

`flutter_secure_storage` を `shared_preferences` に置き換え。

```dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/api_endpoints.dart';

// ... ApiResponse class unchanged ...

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

  // ... _initializeDio() unchanged ...

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

  /// Set authentication token
  Future<void> setAuthToken(String token, [String? refreshToken]) async {
    debugPrint('Storing auth token - length: ${token.length}');
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
  // Auto-login Methods
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

  // ... rest of the file unchanged ...
}
```

### 5. websocket_token_service.dart 変更

同様に `flutter_secure_storage` を `shared_preferences` に置き換え。

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client_service.dart';

class WebSocketTokenService {
  static const String _tokenKey = 'osd_websocket_token';
  static const String _tokenExpiryKey = 'osd_websocket_token_expiry';
  static const int _refreshThresholdDays = 7;

  SharedPreferences? _prefs;
  final ApiClientService _apiClient;

  String? _cachedToken;
  DateTime? _cachedExpiry;

  static WebSocketTokenService? _instance;
  static WebSocketTokenService get instance {
    _instance ??= WebSocketTokenService._internal();
    return _instance!;
  }

  WebSocketTokenService._internal() : _apiClient = ApiClientService.instance;

  /// Get SharedPreferences instance (lazy initialization)
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Load cached token from storage
  Future<void> _loadCachedToken() async {
    try {
      final prefs = await _getPrefs();
      _cachedToken = prefs.getString(_tokenKey);
      final expiryStr = prefs.getString(_tokenExpiryKey);

      if (expiryStr != null) {
        _cachedExpiry = DateTime.tryParse(expiryStr);
      }
      // ... rest unchanged
    } catch (e) {
      debugPrint('Error loading cached token: $e');
    }
  }

  /// Save token to storage
  Future<void> _saveToken(String token, DateTime expiry) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_tokenExpiryKey, expiry.toIso8601String());
      _cachedToken = token;
      _cachedExpiry = expiry;
    } catch (e) {
      debugPrint('Error saving token: $e');
    }
  }

  /// Clear stored token
  Future<void> clearToken() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_tokenKey);
      await prefs.remove(_tokenExpiryKey);
      _cachedToken = null;
      _cachedExpiry = null;
    } catch (e) {
      debugPrint('Error clearing token: $e');
    }
  }

  // ... rest of the file unchanged ...
}
```

### 6. login_screen.dart 変更

自動ログイン機能を追加。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/auth_service.dart';
import 'display_selection_screen.dart';
import 'order_status_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  /// Check if auto-login is configured and perform auto-login
  Future<void> _checkAutoLogin() async {
    // Only auto-login in kiosk mode
    final platformMode = dotenv.env['PLATFORM_MODE'] ?? 'standard';
    if (platformMode != 'kiosk') {
      return;
    }

    final autoEmail = dotenv.env['AUTO_LOGIN_EMAIL'] ?? '';
    final autoPassword = dotenv.env['AUTO_LOGIN_PASSWORD'] ?? '';

    if (autoEmail.isNotEmpty && autoPassword.isNotEmpty) {
      // Set credentials and trigger auto-login
      _emailController.text = autoEmail;
      _passwordController.text = autoPassword;

      // Small delay to ensure widget is fully built
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _handleLogin();
      }
    }
  }

  // ... rest of the file unchanged ...
}
```

### 7. osd_websocket_service.dart 変更

エラーハンドリングの強化（rasp_ver版のコードを採用）。

```dart
// order_created イベントハンドラの変更部分

_socket!.on('order_created', (data) {
  debugPrint('[OSD] New order received via order_created');
  debugPrint('   Raw data type: ${data.runtimeType}');
  debugPrint('   Raw data keys: ${data is Map<String, dynamic> ? data.keys.toList() : 'N/A'}');

  try {
    if (data is Map<String, dynamic>) {
      // Send ACK if required
      _sendMessageAck(data);

      // Extract orderData from nested structure
      final orderData = data['orderData'] as Map<String, dynamic>? ?? data;
      debugPrint('   Extracted orderData keys: ${orderData.keys.toList()}');
      debugPrint('   Order ID: ${orderData['orderId'] ?? orderData['id'] ?? 'N/A'}');
      debugPrint('   Order Number: ${orderData['orderNumber'] ?? orderData['order_number'] ?? 'N/A'}');

      // Try to parse OsdOrder with fallback
      OsdOrder? osdOrder;
      try {
        osdOrder = OsdOrder.fromWebSocketEvent(orderData);
        debugPrint('   Parsed OsdOrder: ID=${osdOrder.id}, CallNumber=${osdOrder.callNumber}');
      } catch (parseError, parseStackTrace) {
        debugPrint('   Warning: Failed to parse OsdOrder from WebSocket data: $parseError');
        debugPrint('   This is OK - will fetch from DB instead');

        // Create minimal OsdOrder with just the ID to trigger DB fetch
        final orderId = orderData['orderId'] ?? orderData['order_id'] ?? orderData['id']?.toString() ?? 'unknown';

        int? parseIntOrNull(dynamic value) {
          if (value == null) return null;
          if (value is int) return value;
          if (value is String) return int.tryParse(value);
          return null;
        }

        osdOrder = OsdOrder(
          id: orderId,
          callNumber: parseIntOrNull(orderData['callNumber'] ?? orderData['call_number']),
          tableNumber: parseIntOrNull(orderData['tableNumber'] ?? orderData['table_number']),
          orderNumber: orderData['orderNumber']?.toString() ?? orderData['order_number']?.toString(),
          diningOption: orderData['diningOption']?.toString() ?? orderData['dining_option']?.toString(),
          displayStatus: 'pending',
          createdAt: DateTime.now(),
        );
        debugPrint('   Created minimal OsdOrder for DB fetch trigger: ID=$orderId');
      }

      if (osdOrder != null) {
        _notificationsReceived++;
        onNewOrder?.call(osdOrder);
        notifyListeners();
        debugPrint('   onNewOrder callback executed successfully');
      }
    } else {
      debugPrint('   Invalid data format: ${data.runtimeType}');
    }
  } catch (e, stackTrace) {
    debugPrint('Error processing order_created: $e');
    debugPrint('   Stack trace: $stackTrace');

    // Fallback: try to trigger DB fetch with extracted order ID
    try {
      if (data is Map<String, dynamic>) {
        final orderData = data['orderData'] as Map<String, dynamic>? ?? data;
        final orderId = orderData['orderId'] ?? orderData['order_id'] ?? orderData['id']?.toString();
        if (orderId != null) {
          debugPrint('   Attempting fallback DB fetch with orderId: $orderId');
          final minimalOrder = OsdOrder(
            id: orderId.toString(),
            displayStatus: 'pending',
            createdAt: DateTime.now(),
          );
          onNewOrder?.call(minimalOrder);
          debugPrint('   Fallback DB fetch triggered');
        }
      }
    } catch (fallbackError) {
      debugPrint('   Failed to trigger fallback: $fallbackError');
    }
  }
});
```

### 8. Android build.gradle.kts 変更

```kotlin
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.sciometa.osd"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // ... compileOptions, kotlinOptions unchanged ...

    defaultConfig {
        applicationId = "com.sciometa.osd"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
```

### 9. MainActivity.kt パス変更

```
変更前: android/app/src/main/kotlin/com/sciometa/osd_app/MainActivity.kt
変更後: android/app/src/main/kotlin/com/sciometa/osd/MainActivity.kt
```

```kotlin
package com.sciometa.osd

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()
```

---

## ファイル変更一覧

| ファイル | 変更種別 | 説明 |
|---------|---------|------|
| `flutter_app/.env` | 変更 | `PLATFORM_MODE`, `AUTO_LOGIN_*`, `KIOSK_*` 追加 |
| `flutter_app/pubspec.yaml` | 変更 | `flutter_secure_storage`削除、`window_manager`追加 |
| `flutter_app/lib/main.dart` | 変更 | ウィンドウマネージャー初期化追加 |
| `flutter_app/lib/services/api_client_service.dart` | 変更 | SharedPreferencesに変更 |
| `flutter_app/lib/services/websocket_token_service.dart` | 変更 | SharedPreferencesに変更 |
| `flutter_app/lib/services/osd_websocket_service.dart` | 変更 | エラーハンドリング強化 |
| `flutter_app/lib/screens/login_screen.dart` | 変更 | 自動ログイン機能追加 |
| `flutter_app/android/app/build.gradle.kts` | 変更 | namespace変更、署名設定追加 |
| `flutter_app/android/app/src/main/kotlin/.../MainActivity.kt` | 移動 | パッケージ名変更に伴う移動 |

---

## 環境別設定例

### 通常版 (Android/iOS/Mac/Windows)

```env
FLUTTER_ENV=production
PLATFORM_MODE=standard
AUTO_LOGIN_EMAIL=
AUTO_LOGIN_PASSWORD=
```

### Raspberry Pi / キオスクモード

```env
FLUTTER_ENV=production
PLATFORM_MODE=kiosk
AUTO_LOGIN_EMAIL=display@example.com
AUTO_LOGIN_PASSWORD=secure_password
KIOSK_FULLSCREEN=true
KIOSK_ALWAYS_ON_TOP=true
KIOSK_SKIP_TASKBAR=true
```

### 開発環境

```env
FLUTTER_ENV=development
PLATFORM_MODE=standard
ENABLE_VERBOSE_LOGGING=true
```

---

## セキュリティ考慮事項

### ストレージの変更について

| 観点 | 評価 |
|------|------|
| トークンの保存 | SharedPreferencesは暗号化されないが、OSD端末は専用ディスプレイのため許容範囲 |
| パスワードの保存 | 自動ログイン用のみ、キオスクモード限定 |
| 推奨事項 | 本番環境では自動ログインパスワードを定期的に変更することを推奨 |

### Raspberry Pi固有の考慮事項

1. **物理的セキュリティ**: 端末へのアクセス制限を実施
2. **ネットワーク**: 専用VLANでの運用を推奨
3. **自動更新**: 定期的なセキュリティアップデートの適用

---

## テスト項目

### 機能テスト

| # | テスト項目 | 対象プラットフォーム |
|---|-----------|-------------------|
| 1 | 通常ログイン動作確認 | 全プラットフォーム |
| 2 | 自動ログイン動作確認 (PLATFORM_MODE=kiosk) | Linux, Windows, macOS |
| 3 | フルスクリーン表示確認 | Linux, Windows, macOS |
| 4 | WebSocket接続・再接続確認 | 全プラットフォーム |
| 5 | 注文ステータス表示確認 | 全プラットフォーム |
| 6 | トークン保存・復元確認 | 全プラットフォーム |

### 回帰テスト

| # | テスト項目 | 確認事項 |
|---|-----------|---------|
| 1 | Android通常起動 | ストレージ変更による影響なし |
| 2 | iOS通常起動 | ストレージ変更による影響なし |
| 3 | 既存ユーザーデータ移行 | 必要に応じてデータ移行スクリプト検討 |

---

## 実装手順

### Phase 1: 依存関係の変更

1. `pubspec.yaml` から `flutter_secure_storage` を削除
2. `window_manager` を追加
3. `flutter pub get` を実行

### Phase 2: ストレージ実装の変更

1. `api_client_service.dart` を更新
2. `websocket_token_service.dart` を更新
3. 動作確認

### Phase 3: ウィンドウ管理・自動ログイン

1. `main.dart` にウィンドウマネージャー初期化を追加
2. `login_screen.dart` に自動ログイン機能を追加
3. `.env` ファイルを更新

### Phase 4: WebSocket強化

1. `osd_websocket_service.dart` のエラーハンドリングを強化

### Phase 5: Android設定変更

1. `build.gradle.kts` を更新
2. `MainActivity.kt` を移動
3. Androidビルド確認

### Phase 6: テスト・検証

1. 各プラットフォームでの動作確認
2. 回帰テストの実施
3. Raspberry Piでのキオスクモードテスト

---

## 参考資料

- [docs/raspberry-pi-setup.md](./raspberry-pi-setup.md) - Raspberry Piセットアップガイド
- [docs/requirements-specification.md](./requirements-specification.md) - OSD要件仕様書
