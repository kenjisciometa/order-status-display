# OSD トークンリフレッシュ競合修正 定義書

## 概要

OSD (Order Status Display) の Dio インターセプターにおいて、401 レスポンス発生時のトークンリフレッシュ処理に以下の保護パターンが欠如しており、デバイスロックアウトや無限ループが発生するリスクがある。KDS/SDS/CDS/SelfStation と同一の修正を適用する。

## 対象ファイル

`order-status-display/flutter_app/lib/services/api_client_service.dart`

## 現在の実装状況

| パターン | 状態 | 説明 |
|----------|------|------|
| P1: Completer ロック | ✅ 実装済み | `_refreshCompleter`（61行目） |
| P2: `_authRetried` フラグ | ❌ 未実装 | リトライ後の無限 401 ループ防止 |
| P3: 連続失敗カウンター | ❌ 未実装 | 連続失敗時のトークン強制クリア |
| P4: プリリクエスト期限チェック | ❌ 未実装 | 401 発生前にトークンを事前リフレッシュ |
| 認証エンドポイントスキップ | ❌ 未実装 | `onError` で認証エンドポイント自体の 401 をスキップ |

## OSD 固有差分

| 項目 | OSD | SDS/CDS |
|------|-----|---------|
| ストレージ | `SharedPreferences` | `FlutterSecureStorage` |
| ログプレフィックス | `[OSD API CLIENT]` | `[SDS/CDS API CLIENT]` |
| `_isAuthEndpoint()` | **なし（追加必要）** | あり |
| レスポンスパース | `data['session']['access_token']` | 同一 |
| `setAuthToken()` | 2引数 `(token, refreshToken?)` | 同一 |
| 認証エンドポイント | `/api/auth/*` | 同一 |
| `onRequest` Bearer ログ | `debugPrint` あり（454行目） | なし |

## 修正案

### OSD-1: import 追加（1行目付近）

```dart
import 'dart:async';  // 既存
import 'dart:convert'; // 追加: JWT デコード用
```

### OSD-2: フィールド追加（61行目付近）

```dart
  Completer<bool>? _refreshCompleter;  // 既存

  /// 連続リフレッシュ失敗回数（P3）
  int _consecutiveRefreshFailures = 0;
  static const int _maxConsecutiveRefreshFailures = 3;
```

### OSD-3: JWT デコードヘルパー追加（`clearAuthData()` の後、148行目付近）

```dart
  // ===================
  // Token Expiry Helpers
  // ===================

  /// JWT ペイロードをデコード
  Map<String, dynamic>? _decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// トークンが期限切れかチェック
  Future<bool> isTokenExpired() async {
    final token = await getAuthToken();
    if (token == null) return true;
    try {
      final payload = _decodeToken(token);
      if (payload == null || payload['exp'] is! int) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(
          (payload['exp'] as int) * 1000);
      return DateTime.now().isAfter(expiry);
    } catch (e) {
      return true;
    }
  }

  /// トークンが5分以内に期限切れになるかチェック
  Future<bool> isTokenExpiringSoon() async {
    final token = await getAuthToken();
    if (token == null) return true;
    try {
      final payload = _decodeToken(token);
      if (payload == null || payload['exp'] is! int) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(
          (payload['exp'] as int) * 1000);
      return expiry.difference(DateTime.now()).inMinutes <= 5;
    } catch (e) {
      return true;
    }
  }
```

### OSD-4: `refreshAuthToken()` 置き換え（203-256行目）

既存の Completer ロジックを維持し、P3（連続失敗カウンター）を追加。

```dart
  /// Refresh authentication token
  /// Completer で同時呼び出しを1つに集約（P1: 既存）
  /// 連続失敗カウンターで無限リトライを防止（P3: 追加）
  Future<bool> refreshAuthToken() async {
    if (_refreshCompleter != null) {
      debugPrint('🔒 [OSD API CLIENT] Token refresh already in progress, waiting...');
      return _refreshCompleter!.future;
    }

    // P3: 連続失敗の上限チェック（追加）
    if (_consecutiveRefreshFailures >= _maxConsecutiveRefreshFailures) {
      debugPrint(
          '❌ [OSD API CLIENT] Max consecutive refresh failures reached, clearing tokens');
      await clearAuthData();
      return false;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        debugPrint('⚠️ [OSD API CLIENT] No refresh token available');
        _consecutiveRefreshFailures++;  // P3
        _refreshCompleter!.complete(false);
        return false;
      }

      debugPrint('🔄 [OSD API CLIENT] Attempting token refresh...');

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
          _consecutiveRefreshFailures = 0;  // P3: 成功でリセット
          _refreshCompleter!.complete(true);
          return true;
        }
      }

      debugPrint(
          '❌ [OSD API CLIENT] Token refresh failed: ${response.statusCode}');
      await clearAuthData();
      _consecutiveRefreshFailures++;  // P3
      _refreshCompleter!.complete(false);
      return false;
    } on DioException catch (e) {
      debugPrint('❌ [OSD API CLIENT] Token refresh error: $e');
      if (e.response?.statusCode == 400 || e.response?.statusCode == 401) {
        await clearAuthData();
      }
      _consecutiveRefreshFailures++;  // P3
      _refreshCompleter!.complete(false);
      return false;
    } catch (e) {
      debugPrint('❌ [OSD API CLIENT] Token refresh error: $e');
      _consecutiveRefreshFailures++;  // P3
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }
```

### OSD-5: `_AuthInterceptor` に `_isAuthEndpoint()` 追加（435行目付近）

OSD には認証エンドポイント判定メソッドが存在しないため、新規追加する。

```dart
class _AuthInterceptor extends Interceptor {
  final ApiClientService _apiClient;

  _AuthInterceptor(this._apiClient);

  /// 認証エンドポイントかどうかを判定
  static const List<String> _authEndpoints = [
    '/api/auth/login',
    '/api/auth/signup',
    '/api/auth/refresh',
    '/api/auth/logout',
    '/api/auth/reset-password',
    '/api/auth/google-native',
  ];

  bool _isAuthEndpoint(String path) {
    return _authEndpoints.any((endpoint) => path.contains(endpoint));
  }

  // ...
}
```

### OSD-6: `_AuthInterceptor.onRequest()` 置き換え（438-458行目）

P4（プリリクエスト期限チェック）を追加。OSD 既存の Bearer トークンログ出力は維持する。

```dart
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

    // P4: 認証エンドポイント以外で期限切れ or 期限間近なら事前リフレッシュ（追加）
    if (!_isAuthEndpoint(options.path)) {
      try {
        final isExpired = await _apiClient.isTokenExpired();
        final isExpiringSoon = await _apiClient.isTokenExpiringSoon();
        if (isExpired || isExpiringSoon) {
          debugPrint('🔄 [OSD API CLIENT] Token expiring soon, pre-refreshing...');
          await _apiClient.refreshAuthToken();
        }
      } catch (e) {
        debugPrint('⚠️ [OSD API CLIENT] Token expiry check failed: $e');
      }
    }

    // Add auth token if available
    final token = await _apiClient.getAuthToken();
    if (token != null) {
      options.headers[ApiHeaders.authorization] = 'Bearer $token';
      debugPrint(
          '✅ [OSD API CLIENT] Adding Bearer token to request: ${options.uri}');
    }

    handler.next(options);
  }
```

### OSD-7: `_AuthInterceptor.onError()` 置き換え（460-494行目）

P2（`_authRetried` フラグ）と認証エンドポイントスキップを追加。

```dart
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestPath = err.requestOptions.path;

    // 認証エンドポイントの 401 はリフレッシュをスキップ（追加）
    if (_isAuthEndpoint(requestPath)) {
      debugPrint(
          '⚠️ [OSD API CLIENT] Auth endpoint error, skipping recovery: $requestPath');
      handler.next(err);
      return;
    }

    // Handle 401 Unauthorized - attempt token refresh
    if (err.response?.statusCode == 401) {
      // P2: リトライ済みなら再試行しない（追加）
      if (err.requestOptions.extra['_authRetried'] == true) {
        debugPrint(
            '❌ [OSD API CLIENT] Already retried after refresh, not retrying again');
        await _apiClient.clearAuthData();
        handler.next(err);
        return;
      }

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
            retryOptions.extra['_authRetried'] = true; // P2（追加）

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
```

---

## 修正後の保護パターン一覧

| パターン | 修正前 | 修正後 |
|----------|--------|--------|
| P1: Completer ロック | ✅ 既存 | ✅ 既存 |
| P2: `_authRetried` フラグ | ❌ | ✅ 新規 |
| P3: 連続失敗カウンター | ❌ | ✅ 新規 |
| P4: プリリクエスト期限チェック | ❌ | ✅ 新規 |
| 認証エンドポイントスキップ | ❌ | ✅ 新規 |

## 動作シナリオ

### シナリオ 1: 複数の同時 401

```
A,B,C → 401

A: onError → refreshAuthToken() → P1: Completer 作成 → POST /api/auth/refresh
B: onError → refreshAuthToken() → P1: Completer 待機
C: onError → refreshAuthToken() → P1: Completer 待機

サーバー: 成功 → complete(true) → P3: _consecutiveRefreshFailures = 0

A: true → リトライ（P2: _authRetried=true） → 成功
B: true → リトライ（P2: _authRetried=true） → 成功
C: true → リトライ（P2: _authRetried=true） → 成功

clearAuthData() は呼ばれない ✅
```

### シナリオ 2: リフレッシュトークンが正当に期限切れ

```
A → 401

A: onError → refreshAuthToken() → P3: failures < 3 → POST
サーバー: 失敗 → complete(false) → P3: failures++

A: false → clearAuthData() → トークン削除
→ 次の API: トークンなし → 401 → refresh token なし → 即 false → P3: failures++
→ 3回目: P3: failures >= 3 → clearAuthData() → 即 return false

無限ループにならない ✅
```

### シナリオ 3: リトライ後に再度 401

```
A → 401 → refresh 成功 → リトライ（P2: _authRetried=true）→ 再び 401

A: onError → P2: _authRetried == true → clearAuthData() → handler.next(err)

無限ループにならない ✅
```

### シナリオ 4: プリリクエスト期限チェックで 401 を回避

```
A: onRequest → P4: isTokenExpiringSoon() == true → refreshAuthToken()
→ 新トークンで本来のリクエスト送信 → 200 成功

401 が発生しない ✅
```

## 変更箇所サマリ

| # | 変更 | 行番号（現行） | 内容 |
|---|------|---------------|------|
| 1 | import 追加 | 1行目付近 | `import 'dart:convert';` |
| 2 | フィールド追加 | 61行目の後 | `_consecutiveRefreshFailures` + `_maxConsecutiveRefreshFailures` |
| 3 | JWT ヘルパー追加 | 148行目の後 | `_decodeToken()`, `isTokenExpired()`, `isTokenExpiringSoon()` |
| 4 | `refreshAuthToken()` 置き換え | 203-256行目 | P3 カウンター追加 |
| 5 | `_isAuthEndpoint()` 追加 | 432-435行目 | 認証エンドポイント判定メソッド新規追加 |
| 6 | `onRequest()` 置き換え | 438-458行目 | P4 追加 |
| 7 | `onError()` 置き換え | 460-494行目 | P2 + 認証エンドポイントスキップ追加 |
