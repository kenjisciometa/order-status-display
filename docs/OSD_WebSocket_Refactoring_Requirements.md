# OSD WebSocket実装改修要件定義書

## 文書情報
- **作成日**: 2026-01-27
- **バージョン**: 1.0
- **対象システム**: Order Status Display (OSD) Flutter App

---

## 1. 概要

### 1.1 改修目的
OSDのWebSocket実装をKDSと同じアーキテクチャに変更し、データの信頼性と一貫性を向上させる。

### 1.2 現状の問題点
1. **WebSocketイベントデータの直接使用**
   - 現在: WebSocketの`order_created`イベントのペイロードをそのまま使用
   - 問題: BOS（Backend Order Service）はPOSからのHTTP POST受信直後にブロードキャストするため、DB保存前のデータ（`callNumber: null`等）が送信される可能性がある

2. **定期リフレッシュの存在**
   - 現在: `_setupPeriodicRefresh()`による定期的なDB問い合わせ
   - 問題: WebSocketイベントでDB再取得する場合、定期リフレッシュは冗長であり不要な負荷となる

### 1.3 目標アーキテクチャ
KDSの「PURE WEBSOCKET MODE」パターンを採用:
- WebSocketイベントは**トリガー**としてのみ使用
- 実際のデータは常に**DBから取得**
- 定期リフレッシュ（ポーリング）は**完全削除**
- UIの経過時間更新用の**クロックタイマーのみ**残す

---

## 2. 現状実装分析

### 2.1 データフロー（現状）
```
POS → BOS (WebSocket Server) → OSD
         ↓
    order_created イベント
         ↓
    OSD: イベントデータを直接使用 ← 問題箇所
```

### 2.2 データフロー（目標：KDS方式）
```
POS → BOS (WebSocket Server) → OSD
         ↓
    order_created イベント（トリガーのみ）
         ↓
    OSD: _loadOrders() 呼び出し
         ↓
    OSD → Supabase API → DB
         ↓
    完全なデータを取得（callNumber含む）
```

### 2.3 KDS参照実装
**ファイル**: `order_sys/kds/flutter_app/lib/screens/order_display_screen.dart`

```dart
// KDSのタイマー実装（ポーリングなし）
void _startTimers() {
  // NO POLLING: Custom WebSocket + Database Triggers handle all real-time updates
  if (kDebugMode) {
    debugPrint(
        '✅ KDS PURE WEBSOCKET MODE: No polling - Custom WebSocket + Database Triggers handle all instant updates');
  }

  // UIの経過時間表示用タイマーのみ
  _clockTimer?.cancel();
  _clockTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
    if (mounted) setState(() {});
  });
}

// WebSocketイベント受信時はDBから再取得
_kdsNotificationService.onOrderInserted = (order) {
  if (kDebugMode) {
    debugPrint('🆕 KDS WebSocket: New order received: ${order['id']}');
  }
  _loadOrders();  // ← DBからデータ再取得
};
```

---

## 3. 改修対象ファイル

### 3.1 order_status_screen.dart
**パス**: `order-status-display/flutter_app/lib/screens/order_status_screen.dart`

#### 削除対象
- `_setupPeriodicRefresh()` メソッド全体
- `_refreshTimer` 変数と関連するキャンセル処理
- 定期リフレッシュに関連するすべてのコード

#### 変更対象
- `_startTimers()` メソッドをKDS方式に変更
- WebSocketコールバックでの`_loadOrders()`呼び出し追加

### 3.2 osd_websocket_service.dart
**パス**: `order-status-display/flutter_app/lib/services/osd_websocket_service.dart`

#### 変更対象
- `onNewOrder` コールバックの用途変更
  - 現状: イベントデータを返却
  - 変更後: トリガーとしてのみ機能（データは無視してもよい）

### 3.3 osd_order.dart
**パス**: `order-status-display/flutter_app/lib/models/osd_order.dart`

#### 確認事項
- `fromWebSocketEvent()` は引き続きフォールバックとして保持（オプション）
- 主要データソースは `fromJson()` （API経由）

---

## 4. 詳細改修仕様

### 4.1 order_status_screen.dart の改修

#### 4.1.1 削除するコード
```dart
// 削除: 定期リフレッシュタイマー変数
Timer? _refreshTimer;

// 削除: 定期リフレッシュセットアップメソッド
void _setupPeriodicRefresh() {
  // ... 全体削除
}

// 削除: dispose内の_refreshTimer?.cancel()
```

#### 4.1.2 追加・変更するコード
```dart
// 変更: タイマー実装（KDS方式）
void _startTimers() {
  // OSD PURE WEBSOCKET MODE: ポーリングなし
  debugPrint('✅ OSD PURE WEBSOCKET MODE: No polling - WebSocket events trigger DB fetch');

  // UIの経過時間表示更新用タイマーのみ（500ms間隔）
  _clockTimer?.cancel();
  _clockTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
    if (mounted) setState(() {});
  });
}

// 変更: WebSocketコールバック
void _setupWebSocketCallbacks() {
  // order_createdイベント → DBから再取得
  _webSocketService.onNewOrder = (orderData) {
    debugPrint('🆕 OSD WebSocket: New order event received');
    _loadOrders();  // イベントデータは使わず、DBから取得
  };

  // order_statusイベント → DBから再取得
  _webSocketService.onOrderStatusChanged = (orderData) {
    debugPrint('🔄 OSD WebSocket: Order status changed event received');
    _loadOrders();  // イベントデータは使わず、DBから取得
  };

  // order_deletedイベント → DBから再取得
  _webSocketService.onOrderDeleted = (orderId) {
    debugPrint('🗑️ OSD WebSocket: Order deleted event received');
    _loadOrders();  // ローカル削除ではなくDB再取得で同期
  };
}
```

### 4.2 initState/dispose の変更

#### 4.2.1 initState
```dart
@override
void initState() {
  super.initState();
  _initializeServices();
}

Future<void> _initializeServices() async {
  // WebSocket接続
  await _connectWebSocket();

  // WebSocketコールバック設定
  _setupWebSocketCallbacks();

  // 初回データロード（DB経由）
  await _loadOrders();

  // UIタイマー開始（クロックのみ）
  _startTimers();
}
```

#### 4.2.2 dispose
```dart
@override
void dispose() {
  _clockTimer?.cancel();  // クロックタイマーのみ
  // _refreshTimer?.cancel();  ← 削除
  super.dispose();
}
```

---

## 5. 非機能要件

### 5.1 パフォーマンス
- 定期リフレッシュ削除により、Supabase API呼び出し回数が大幅に削減
- WebSocketイベント発生時のみDB問い合わせ

### 5.2 信頼性
- DBを単一の信頼できるデータソース（Single Source of Truth）として使用
- `callNumber: null` 問題の完全解消

### 5.3 スケーラビリティ
- 同時接続店舗数: Supabase Pro で約50-100店舗を想定
- ポーリング削除によりAPIコール数を最小化

---

## 6. テスト要件

### 6.1 機能テスト
| テスト項目 | 期待結果 |
|-----------|---------|
| 新規注文受信 | WebSocketイベント後、DBから取得した完全なデータが表示される |
| ステータス変更 | WebSocketイベント後、最新のステータスが表示される |
| 注文削除 | WebSocketイベント後、該当注文が画面から削除される |
| 経過時間表示 | 500msごとに正確に更新される |
| 初回ロード | アプリ起動時、DBから全注文が正常に取得される |

### 6.2 異常系テスト
| テスト項目 | 期待結果 |
|-----------|---------|
| WebSocket切断 | 再接続後、DBから最新データを取得 |
| API エラー | エラー表示、リトライ機能 |
| ネットワーク断 | 接続回復後に自動同期 |

---

## 7. 移行計画

### 7.1 実装順序
1. `_setupPeriodicRefresh()` と `_refreshTimer` の削除
2. `_startTimers()` の変更（クロックタイマーのみ）
3. `_setupWebSocketCallbacks()` の変更（DB再取得トリガー）
4. テスト実施
5. デプロイ

### 7.2 ロールバック計画
- Git で改修前のコミットにリバート可能
- 定期リフレッシュコードは完全削除（分岐での保持不要）

---

## 8. 参考資料

### 8.1 関連ファイル
- KDS実装: `order_sys/kds/flutter_app/lib/screens/order_display_screen.dart`
- WebSocketサーバー: `websocket-server/src/server.js`
- OSD Order Service: `order-status-display/flutter_app/lib/services/osd_order_service.dart`

### 8.2 関連ドキュメント
- Supabase API ドキュメント
- Flutter Timer クラスドキュメント
