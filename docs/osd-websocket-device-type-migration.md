# OSD WebSocket デバイスタイプ移行定義書

## 概要

OSD（Order Status Display）アプリケーションのWebSocket接続において、デバイスタイプを`sds_device`から`osd`に変更し、セキュリティ強化のためトークン保存方法を改善する。

## 背景

### 現状の問題点

1. **デバイスタイプの不整合**
   - OSDが`sds_device`タイプを使用しており、SDS（Service Display System）と区別がつかない
   - サーバー側のログ・モニタリングで正確なデバイス識別ができない

2. **セキュリティ脆弱性**
   - OSDのJWTトークンが`SharedPreferences`に平文で保存されている
   - SDS/KDSは`FlutterSecureStorage`（暗号化）を使用

3. **命名規則の不統一**
   - KDS: `kds`
   - CDS: `cds`
   - SDS: `sds` または `sds_device`（混在）
   - BOS: `bos` または `bos_device`（混在）
   - OSD: `sds_device`（誤り）

## 目標

| 項目 | 現状 | 目標 |
|------|------|------|
| OSDデバイスタイプ | `sds_device` | `osd` |
| トークン保存 | `SharedPreferences`（平文） | プラットフォーム別セキュアストレージ |
| 命名規則 | 不統一 | 統一（将来的に全て `_device` サフィックスなし） |

## 修正対象ファイル

### 1. WebSocketサーバー（websocket-server）

#### 1.1 AuthService.js
**パス**: `websocket-server/src/services/AuthService.js`

**修正内容**:
- `osd` および `osd_device` タイプの認証ロジックを追加
- SDS同様に`storeId`で認証

```javascript
// 追加する分岐（92行目付近、sds分岐の後に追加）
} else if (type === 'osd') {
    // For OSD (Order Status Display) devices, validate store-specific claims
    tokenData = {
        deviceId: decoded.sub,
        organizationId: decoded.organization_id,
        storeId: decoded.store_id || identifier,
        displayId: decoded.display_id, // Optional, for filtering
        role: decoded.role || 'osd',
        permissions: decoded.permissions || ['read_orders', 'read_sessions'],
        issuedAt: new Date(decoded.iat * 1000),
        expiresAt: new Date(decoded.exp * 1000)
    };

    // Verify store access
    if (identifier && tokenData.storeId !== identifier) {
        throw new Error(`Token store ID (${tokenData.storeId}) does not match requested store (${identifier})`);
    }
}
```

#### 1.2 server.js
**パス**: `websocket-server/src/server.js`

**修正内容**:
- `isOsdDevice` ヘルパー関数を追加
- 認証フローで`osd`タイプをサポート

```javascript
// 認証分岐に追加（isSdsDevice分岐の後）
} else if (type === 'osd') {
    if (!storeId || !token) {
        throw new Error('Missing OSD authentication credentials');
    }
}
```

### 2. API（ReactRestaurantPOS）

#### 2.1 tokenGenerator.ts
**パス**: `ReactRestaurantPOS/src/lib/websocket/tokenGenerator.ts`

**修正内容**:
- `DEVICE_CONFIGS`に`osd`タイプを追加

```typescript
// DEVICE_CONFIGSに追加
osd: {
  role: 'osd',
  issuer: 'osd-system',
  audience: 'osd-devices',
  permissions: ['read_orders', 'read_sessions'],
},
```

### 3. OSD Flutterアプリ（order-status-display）

#### 3.1 osd_websocket_service.dart
**パス**: `order-status-display/flutter_app/lib/services/osd_websocket_service.dart`

**修正箇所**:

| 行番号 | 現状 | 修正後 |
|--------|------|--------|
| 316 | `'x-device-type': 'sds_device'` | `'x-device-type': 'osd'` |
| 626 | `'type': 'sds_device'` | `'type': 'osd'` |

#### 3.2 websocket_token_service.dart
**パス**: `order-status-display/flutter_app/lib/services/websocket_token_service.dart`

**修正内容**:

1. **デバイスタイプの変更**
   - `'deviceType': 'sds_device'` → `'deviceType': 'osd'`

2. **セキュアストレージへの移行**
   - `SharedPreferences` → `SecureStorageService`（プラットフォーム別実装）

#### 3.3 secure_storage_service.dart（新規作成）
**パス**: `order-status-display/flutter_app/lib/services/secure_storage_service.dart`

**概要**:
プラットフォーム別のセキュアストレージを提供するサービス。Linux/Raspberry Pi環境ではキーリングサービスが利用できない場合があるため、プラットフォームに応じて最適なストレージを選択する。

**プラットフォーム別ストレージ**:

| プラットフォーム | ストレージ方式 | セキュリティレベル |
|----------------|---------------|------------------|
| iOS | Keychain via FlutterSecureStorage | 高 |
| Android | EncryptedSharedPreferences | 高 |
| macOS | Keychain via FlutterSecureStorage | 高 |
| Windows | Windows Credential Manager | 高 |
| Linux/Raspberry Pi | Hive暗号化ボックス（AES-256） | 中〜高 |

**Linux環境の暗号化**:
- Hive暗号化ボックスを使用（キーリング不要）
- 暗号化キーはデバイス固有の情報から派生
- キーファイルは`chmod 600`で保護
- `libsecret`や`gnome-keyring`への依存なし

```dart
// SecureStorageServiceの使用例
final storage = SecureStorageService.instance;
await storage.initialize();

// 読み書き
await storage.write(key: 'token', value: 'jwt_token_here');
final token = await storage.read(key: 'token');
await storage.delete(key: 'token');

// ストレージタイプの確認（デバッグ用）
print(storage.storageType); // "FlutterSecureStorage" or "Hive (encrypted)"
```

#### 3.4 pubspec.yaml
**パス**: `order-status-display/flutter_app/pubspec.yaml`

**追加依存関係**:

```yaml
# Secure Storage (platform-specific)
# - iOS/Android/macOS/Windows: FlutterSecureStorage (Keychain/EncryptedPrefs)
# - Linux/Raspberry Pi: Hive encrypted box (no keyring dependency)
flutter_secure_storage: ^9.2.2
hive_flutter: ^1.1.0
path_provider: ^2.1.2
crypto: ^3.0.3
```

## 認証フロー（修正後）

```
┌─────────────────┐
│   OSD Flutter   │
│      App        │
└────────┬────────┘
         │ 1. POST /api/websocket/token
         │    { deviceType: 'osd', storeId, organizationId, displayId }
         ▼
┌─────────────────┐
│  ReactRestaurant│
│      POS API    │
└────────┬────────┘
         │ 2. Generate JWT with osd role
         ▼
┌─────────────────┐
│   OSD Flutter   │
│      App        │
└────────┬────────┘
         │ 3. Connect WebSocket
         │    emit('authenticate', { type: 'osd', token, storeId })
         ▼
┌─────────────────┐
│   WebSocket     │
│     Server      │
└────────┬────────┘
         │ 4. Validate token (AuthService.js)
         │    - type: 'osd' → use storeId as identifier
         │    - Verify store access
         ▼
┌─────────────────┐
│   Authenticated │
│    Connection   │
└─────────────────┘
```

## 後方互換性

### 概要

本修正は**後方互換性を維持**しています。古いバージョンのOSDアプリが稼働している環境でも、サーバー側の修正後に問題なく動作します。

### コンポーネント別の更新タイミング

| コンポーネント | 更新タイミング | 制御可能性 |
|---------------|---------------|-----------|
| WebSocketサーバー | 即時デプロイ可能 | ✅ 制御可能 |
| API（ReactRestaurantPOS） | 即時デプロイ可能 | ✅ 制御可能 |
| OSD Flutterアプリ | ユーザーが更新するまで古いバージョンが稼働 | ❌ 制御不可 |

### 互換性マトリクス

**古いOSDアプリは`sds_device`タイプを送信し続けますが、サーバー側のSDS認証ロジックで正常に処理されます。**

| OSDアプリバージョン | 送信タイプ | サーバー処理 | 結果 |
|-------------------|-----------|-------------|------|
| 古い（未更新） | `sds_device` | SDS認証ロジック | ✅ 動作する |
| 新しい（更新済み） | `osd` | OSD認証ロジック | ✅ 動作する |

### 認証フロー（古いアプリの場合）

```
古いOSDアプリ
    │
    │ type: 'sds_device'
    ▼
WebSocketサーバー
    │
    │ isSdsDevice('sds_device') → true
    │ SDS認証ロジックで処理
    ▼
認証成功 ✅
```

### サポートするデバイスタイプ一覧

| タイプ | サポート | 用途 | 備考 |
|--------|----------|------|------|
| `osd` | ✅ | OSD（新規） | 推奨・唯一のOSDタイプ |
| `osd_device` | ❌ | - | 実装しない（過去に使用実績なし） |
| `sds_device` | ✅ | SDS / 古いOSD | 古いOSDアプリはこれを使用（後方互換性） |
| `sds` | ✅ | SDS | 推奨 |

### 注意点・制限事項

1. **ログ・モニタリングの制限**
   - 古いOSDアプリはサーバーログで`sds_device`として記録される
   - OSDとSDSの区別がつかない（現状と同じ動作）
   - 新しいアプリに更新されるまでこの状態が続く

2. **将来的な機能拡張時の考慮**
   - OSD固有の機能を追加する場合、古いアプリでは利用できない
   - 必要に応じて強制アップデートを検討

3. **移行完了の判断**
   - サーバーログで`sds_device`からのOSD接続がなくなった時点で移行完了と判断
   - その後、`sds_device`をOSD用として扱うロジックの削除を検討可能

### デプロイ順序と互換性

```
1. サーバー側デプロイ（AuthService.js, server.js）
   └─ 古いアプリ: sds_device → SDS認証 → ✅ 動作
   └─ 新しいアプリ: osd → OSD認証 → ✅ 動作

2. API側デプロイ（tokenGenerator.ts）
   └─ 古いアプリ: sds_device トークン要求 → ✅ 発行
   └─ 新しいアプリ: osd トークン要求 → ✅ 発行

3. OSDアプリ配布
   └─ ユーザーが随時更新
   └─ 古いアプリも新しいアプリも同時に稼働可能
```

## テスト項目

### 機能テスト

1. **認証テスト**
   - [ ] OSDアプリがWebSocketサーバーに正常に接続できる
   - [ ] トークン取得API（`/api/websocket/token`）が`osd`タイプを受け入れる
   - [ ] サーバー側で`osd`タイプとして正しく認識される

2. **セキュリティテスト**
   - [ ] iOS/Android: トークンが`FlutterSecureStorage`に保存される
   - [ ] Linux: トークンがHive暗号化ボックスに保存される
   - [ ] 平文でトークンが保存されていないことを確認
   - [ ] ストレージタイプがログに正しく表示される

3. **リアルタイム通知テスト**
   - [ ] `order_created`イベントを受信できる
   - [ ] `order_ready_notification`イベントを受信できる
   - [ ] `order_served_notification`イベントを受信できる

### 回帰テスト

1. **他システムへの影響なし**
   - [ ] KDS接続に影響なし
   - [ ] SDS接続に影響なし
   - [ ] CDS接続に影響なし
   - [ ] BOS接続に影響なし

## 実装順序

1. ✅ WebSocketサーバー（AuthService.js）に`osd`タイプ追加
2. ✅ WebSocketサーバー（server.js）に`osd`タイプ追加
3. ✅ API（tokenGenerator.ts）に`osd`タイプ追加
4. ✅ OSD Flutterアプリのデバイスタイプを`osd`に変更
5. ✅ OSD Flutterアプリにプラットフォーム別セキュアストレージを実装
6. テスト実施
7. デプロイ

## 将来の検討事項

### デバイスタイプ命名規則の統一

現在の状態:
- `kds` / `kds_device`（混在）
- `sds` / `sds_device`（混在）
- `bos` / `bos_device`（混在）
- `cds`（統一済み）
- `osd`（新規、統一済み）

将来的には全て`_device`サフィックスなしに統一することを推奨:
- `kds`
- `sds`
- `bos`
- `cds`
- `osd`

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|----------|
| 2026-02-11 | 1.0 | 初版作成 |
| 2026-02-11 | 1.1 | 後方互換性セクションを詳細化 |
| 2026-02-11 | 1.2 | `osd_device`サポートを削除、`osd`のみに統一 |
| 2026-02-11 | 1.3 | プラットフォーム別セキュアストレージ実装を追加（Linux/Raspberry Pi対応） |
