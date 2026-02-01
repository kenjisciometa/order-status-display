# WebSocket接続安定化実装

**実装日**: 2026-01-31
**対象**: Order Status Display (OSD) アプリ

## 概要

アプリ起動時にWebSocket接続が確立されない問題を解決するため、以下の3つの改善を実装しました。

---

## 実装した改善案

### 案1: 起動時リトライ強化

**ファイル**: `lib/services/osd_websocket_service.dart`

アプリ起動時に即座に接続を試みるのではなく、初期接続専用のリトライロジックを追加。

```dart
/// 案1: 起動時の接続リトライ強化
Future<void> connectWithInitialRetry(
  String storeId,
  String? token, {
  String? deviceId,
  String? displayId,
  String? organizationId,
  int maxAttempts = 5,
  Duration baseDelay = const Duration(seconds: 2),
}) async {
  debugPrint('🚀 [OSD-INITIAL-CONNECT] Starting connection with initial retry (max $maxAttempts attempts)');

  // ネットワーク監視を開始
  _startNetworkMonitoring();

  _isInitialConnection = true;

  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    debugPrint('🔄 [OSD-INITIAL-CONNECT] Attempt $attempt/$maxAttempts');

    // ネットワーク接続を確認
    if (!_hasNetworkConnection) {
      debugPrint('⚠️ [OSD-INITIAL-CONNECT] No network connection, waiting...');
      await Future.delayed(baseDelay);
      continue;
    }

    try {
      await connect(
        storeId,
        token,
        deviceId: deviceId,
        displayId: displayId,
        organizationId: organizationId,
      );

      // 接続成功を少し待って確認
      await Future.delayed(const Duration(seconds: 2));

      if (_isConnected) {
        debugPrint('✅ [OSD-INITIAL-CONNECT] Connection succeeded on attempt $attempt');
        _isInitialConnection = false;
        return;
      }
    } catch (e) {
      debugPrint('⚠️ [OSD-INITIAL-CONNECT] Attempt $attempt failed: $e');
    }

    if (attempt < maxAttempts) {
      // 段階的に待機時間を増加（2秒、4秒、6秒...）
      final delay = baseDelay * attempt;
      debugPrint('⏳ [OSD-INITIAL-CONNECT] Waiting ${delay.inSeconds}s before next attempt...');
      await Future.delayed(delay);
    }
  }

  _isInitialConnection = false;
  debugPrint('⚠️ [OSD-INITIAL-CONNECT] All initial attempts exhausted, falling back to normal reconnection logic');

  // 全試行失敗後は通常の再接続ロジックに委ねる
  if (!_isConnected && !_isReconnecting) {
    _scheduleReconnect(
      storeId,
      deviceId: deviceId,
      displayId: displayId,
      organizationId: organizationId,
    );
  }
}
```

**特徴**:
- 最大5回のリトライ
- 段階的に待機時間を増加（2秒 → 4秒 → 6秒 → 8秒 → 10秒）
- ネットワーク接続がない場合はスキップして待機
- 全試行失敗後は通常の再接続ロジックに委ねる

---

### 案2: ネットワーク状態監視

**ファイル**: `lib/services/osd_websocket_service.dart`
**追加パッケージ**: `connectivity_plus: ^6.0.3`

`connectivity_plus`パッケージを使用してネットワーク接続状態を監視。

```dart
// 案2: ネットワーク状態監視
StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
bool _hasNetworkConnection = true;
bool _isInitialConnection = true; // 案1: 起動時リトライ用フラグ

/// 案2: ネットワーク状態監視を開始
void _startNetworkMonitoring() {
  _connectivitySubscription?.cancel();

  _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
    final hadConnection = _hasNetworkConnection;
    _hasNetworkConnection = results.any((r) => r != ConnectivityResult.none);

    debugPrint('📶 [OSD-NETWORK] Connectivity changed: $results (hasConnection: $_hasNetworkConnection)');

    if (_hasNetworkConnection && !hadConnection) {
      // ネットワーク復帰
      debugPrint('📶 [OSD-NETWORK] Network restored');

      if (!_isConnected && !_isReconnecting && !_isInitialConnection) {
        debugPrint('📶 [OSD-NETWORK] Attempting immediate reconnection...');
        _reconnectAttempts = 0; // リトライカウントをリセット

        if (_currentStoreId != null) {
          connect(
            _currentStoreId!,
            null,
            deviceId: _currentDeviceId,
            displayId: _currentDisplayId,
            organizationId: _currentOrganizationId,
          );
        }
      }
    } else if (!_hasNetworkConnection && hadConnection) {
      // ネットワーク喪失
      debugPrint('📵 [OSD-NETWORK] Network lost, pausing reconnection attempts');
      _reconnectTimer?.cancel();
    }
  });

  // 初期状態を確認
  Connectivity().checkConnectivity().then((results) {
    _hasNetworkConnection = results.any((r) => r != ConnectivityResult.none);
    debugPrint('📶 [OSD-NETWORK] Initial connectivity: $results (hasConnection: $_hasNetworkConnection)');
  });
}

/// ネットワーク監視を停止
void _stopNetworkMonitoring() {
  _connectivitySubscription?.cancel();
  _connectivitySubscription = null;
}
```

**特徴**:
- ネットワーク復帰時に即座に再接続を試行
- ネットワーク喪失時は再接続試行を一時停止
- リトライカウントをリセットして新規接続として扱う

---

### 案5: Socket.IOオプション最適化

**ファイル**: `lib/services/osd_websocket_service.dart`

Socket.IO内蔵の再接続機能を有効化し、短期的な切断に対応。

```dart
// Create Socket.IO connection
// 案5: Socket.IOオプション最適化 - 内蔵の再接続も有効にしてバックアップとする
_socket = IO.io(
    _serverUrl,
    IO.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .setReconnectionAttempts(3) // Socket.IOの短期的な自動再接続を有効化（バックアップ）
        .setTimeout(20000)
        .enableForceNew() // 古い接続の影響を排除
        .enableAutoConnect()
        .enableReconnection() // 再接続機能を有効化
        .setReconnectionDelay(1000) // 1秒から開始（より素早い再接続）
        .setReconnectionDelayMax(5000) // 最大5秒（カスタム再接続との併用のため短め）
        .setAuth({'token': jwtToken})
        .setExtraHeaders({
          'x-device-id': deviceMac,
          'x-device-type': 'sds_device',
        })
        .build());
```

**変更点**:
| 設定 | 変更前 | 変更後 |
|------|--------|--------|
| `setReconnectionAttempts` | 0 (無効) | 3 (有効) |
| `enableReconnection` | なし | 有効化 |
| `setReconnectionDelay` | 3000ms | 1000ms |
| `setReconnectionDelayMax` | 10000ms | 5000ms |

---

## 変更ファイル一覧

### 1. pubspec.yaml

```yaml
# Network monitoring (案2: WebSocket接続安定化)
connectivity_plus: ^6.0.3
```

### 2. lib/services/osd_websocket_service.dart

- `connectivity_plus` パッケージのインポート追加
- ネットワーク監視用の変数追加
- `connectWithInitialRetry()` メソッド追加
- `_startNetworkMonitoring()` メソッド追加
- `_stopNetworkMonitoring()` メソッド追加
- Socket.IOオプションの最適化
- `disconnect()` メソッドにネットワーク監視停止オプション追加
- `dispose()` メソッドにネットワーク監視停止追加
- `getDiagnostics()` に新機能の情報追加

### 3. lib/screens/order_status_screen.dart

- `_connectWebSocket()` を `connectWithInitialRetry()` 呼び出しに変更

---

## 動作フロー

```
アプリ起動
    ↓
connectWithInitialRetry() 呼び出し
    ↓
ネットワーク監視開始 ← 案2
    ↓
最大5回の接続リトライ（2秒→4秒→6秒...）← 案1
    ↓
接続成功 → 完了
    ↓
接続失敗時 → 通常の再接続ロジックに委ねる
    ↓
運用中にネットワーク切断
    ↓
ネットワーク復帰を検知 → 即座に再接続 ← 案2
    ↓
短期的な切断 → Socket.IO内蔵の再接続（1秒〜5秒）← 案5
```

---

## ログ出力例

### 正常接続時
```
🚀 [OSD-INITIAL-CONNECT] Starting connection with initial retry (max 5 attempts)
🔄 [OSD-INITIAL-CONNECT] Attempt 1/5
📶 [OSD-NETWORK] Initial connectivity: [ConnectivityResult.wifi] (hasConnection: true)
OSD: WebSocket connected
🔐 OSD: Sending authentication data
✅ OSD: WebSocket authenticated successfully
✅ [OSD-INITIAL-CONNECT] Connection succeeded on attempt 1
```

### ネットワーク復帰時
```
📶 [OSD-NETWORK] Connectivity changed: [ConnectivityResult.wifi] (hasConnection: true)
📶 [OSD-NETWORK] Network restored
📶 [OSD-NETWORK] Attempting immediate reconnection...
```

### ネットワーク喪失時
```
📶 [OSD-NETWORK] Connectivity changed: [ConnectivityResult.none] (hasConnection: false)
📵 [OSD-NETWORK] Network lost, pausing reconnection attempts
```

---

## 検討したが実装しなかった案

### 案3: 接続準備状態の確認（ヘルスチェック）

接続前にサーバーの疎通確認を行う案。効果が限定的なため今回は見送り。

### 案4: 接続状態の永続化

最後の接続成功状態を保存する案。効果が限定的なため今回は見送り。

---

## テスト方法

1. アプリを起動し、ログで以下を確認:
   - `🚀 [OSD-INITIAL-CONNECT]` が表示される
   - `📶 [OSD-NETWORK] Initial connectivity` が表示される
   - `✅ [OSD-INITIAL-CONNECT] Connection succeeded` が表示される

2. ネットワーク切断→復帰をテスト:
   - 機内モードをON/OFFして、`📶 [OSD-NETWORK]` ログを確認
   - ネットワーク復帰後に自動再接続されることを確認

3. サーバー一時停止をテスト:
   - 起動時にサーバーが応答しない状態で、リトライが行われることを確認
