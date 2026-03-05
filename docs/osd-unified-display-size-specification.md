# OSD 統一ディスプレイサイズ規格 定義書

## 概要

本ドキュメントは、OSDアプリのハードコードされたサイズ値を名前付き定数に集約するための定義書です。
BOSの `lib/core/theme/` の命名規則と構造をベースにしつつ、**現在の表示を完全に維持**します。

### 方針

- **現在の表示を変更しない** — 全ての定数は現在のハードコード値と同一
- **レスポンシブ機能は追加しない** — 3列固定グリッド等の現在の動作を維持
- **マジックナンバーの集約のみ** — 散在するハードコード値に意味のある名前を付ける
- **BOSの命名規則を参考** — ただし値はOSD固有のものをそのまま使用

### 対象リポジトリ

- **BOS（命名規則の参考）:** `order_sys/bos/flutter_app/lib/core/theme/`
- **OSD（適用先）:** `order-status-display/flutter_app/lib/`

---

## 1. スペーシング

### 作成ファイル: `lib/core/theme/app_spacing.dart`

OSDで実際に使用されている値を全て定義します。BOSの6px刻みスケールには縛られず、現在の値（Material Design標準の4/8px刻みを含む）をそのまま採用します。

```dart
/// OSD用スペーシング定義
/// 命名規則: BOSベース (order_sys/bos/flutter_app/lib/core/theme/app_spacing.dart)
/// 値: OSD現在値をそのまま保持
class OsdSpacing {
  OsdSpacing._();

  // === 基本スケール (OSDで使用されている全値) ===
  static const double space0 = 0;
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space14 = 14;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;
}
```

### 現在のOSD値との対応

全て現在値と同一です。値の変更はありません。

| 用途例 | 現在値 | 定数 | 値の変更 |
|--------|--------|------|---------|
| divider height | 2 | `space2` | なし |
| chip padding V | 4 | `space4` | なし |
| card gap, spacing | 6 | `space6` | なし |
| grid padding, button padding | 8 | `space8` | なし |
| card padding H, section spacing | 12 | `space12` | なし |
| badge padding H | 14 | `space14` | なし |
| form padding, list padding | 16 | `space16` | なし |
| settings card padding, header H | 20 | `space20` | なし |
| list padding, section gap | 24 | `space24` | なし |
| body padding | 32 | `space32` | なし |
| progress indicator | 40 | `space40` | なし |
| splash spacing, button height | 48 | `space48` | なし |

---

## 2. 角丸 (Border Radius)

### 同ファイルに定義: `lib/core/theme/app_spacing.dart`

OSDで使用されている全ての角丸値を定義します。BOSスケールに存在しない6, 10を追加します。

```dart
/// OSD用角丸定義
/// BOS準拠 + OSD固有値 (6, 10) を追加
class OsdRadius {
  OsdRadius._();

  static const double none = 0;
  static const double sm = 4;     // バッジ小, chip
  static const double xs = 6;     // chip (display_selection)
  static const double base = 8;   // テキスト入力, エラー, elapsed time
  static const double r10 = 10;   // duration option, 一部ボタン
  static const double md = 12;    // カード通常, READYラベル, ボタン
  static const double lg = 16;    // カードHL, ログイン, 設定, 接続ステータス
  static const double xl = 20;    // 接続インジケータ, メールバッジ
  static const double xxl = 24;   // セットアップヘッダ
  static const double full = 9999;
}
```

### 現在のOSD値との対応

| 使用箇所 | 現在値 | 新定数 | 値の変更 |
|---------|--------|--------|---------|
| DEFAULTバッジ | 4 | `OsdRadius.sm` | なし |
| カテゴリチップ (display_selection) | 6 | `OsdRadius.xs` | なし |
| テキスト入力, エラー, elapsed time | 8 | `OsdRadius.base` | なし |
| duration option, 一部ボタン | 10 | `OsdRadius.r10` | なし |
| カード(通常), READYラベル, ボタン | 12 | `OsdRadius.md` | なし |
| カード(HL), ログインカード, 設定カード | 16 | `OsdRadius.lg` | なし |
| 接続インジケータ, メールバッジ | 20 | `OsdRadius.xl` | なし |
| セットアップヘッダ | 24 | `OsdRadius.xxl` | なし |

---

## 3. タイポグラフィ

### 作成ファイル: `lib/core/theme/app_typography.dart`

OSDで使用されている全てのフォントサイズを定義します。BOS基準の14px以上だけでなく、10-13pxの小さいサイズも含めます。

```dart
/// OSD用タイポグラフィ定義
/// 命名規則: BOSベース (order_sys/bos/flutter_app/lib/core/theme/app_typography.dart)
/// 値: OSD現在値をそのまま保持
class OsdTypography {
  OsdTypography._();

  // === フォントサイズ (OSDで使用されている全値) ===
  static const double fontSize10 = 10;   // DEFAULTバッジ
  static const double fontSize11 = 11;   // カテゴリチップ
  static const double fontSize12 = 12;   // elapsed time, dividerラベル, メールバッジ, メタテキスト
  static const double fontSize13 = 13;   // カテゴリテキスト, description
  static const double fontSize14 = 14;   // READYラベル, subtitle, エラー, step label
  static const double fontSize16 = 16;   // ボタン, display name, ストア名, subtitle
  static const double fontSize18 = 18;   // セクションタイトル, 接続ステータス, version info
  static const double fontSize20 = 20;   // カウントバッジ, ログアウト, 空状態タイトル, duration option
  static const double fontSize22 = 22;   // 設定項目値, info value, sound option
  static const double fontSize24 = 24;   // セクションヘッダ, ログインタイトル, ディスプレイ選択タイトル, 底部ログアウト
  static const double fontSize26 = 26;   // 設定項目タイトル, スイッチタイトル, スライダタイトル
  static const double fontSize32 = 32;   // 画面タイトル (設定, スプラッシュ, セットアップ)
  static const double fontSize48 = 48;   // 注文番号, カラムタイトル, 空状態メッセージ

  // === フォントウェイト (BOS準拠) ===
  static const FontWeight weightNormal = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemibold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;
  static const FontWeight weightExtrabold = FontWeight.w800;
  static const FontWeight weightBlack = FontWeight.w900;

  // === 行間 (BOS準拠) ===
  static const double lineHeightNone = 1;
  static const double lineHeightTight = 1.25;
  static const double lineHeightSnug = 1.375;
  static const double lineHeightNormal = 1.5;
  static const double lineHeightRelaxed = 1.625;

  // === 字間 ===
  static const double letterSpacing05 = 0.5;   // DEFAULTバッジ
  static const double letterSpacing1 = 1;       // READYラベル, 注文番号
  static const double letterSpacing15 = 1.5;    // セクションヘッダ
  static const double letterSpacing2 = 2;       // ハイライト注文番号
}
```

### 現在のOSD値との対応

全て現在値と同一です。値の変更はありません。

| 使用箇所 | 現在値 | 新定数 | 値の変更 |
|---------|--------|--------|---------|
| DEFAULTバッジ | 10px | `fontSize10` | なし |
| カテゴリチップ | 11px | `fontSize11` | なし |
| elapsed time, dividerラベル | 12px | `fontSize12` | なし |
| カテゴリテキスト, description | 13px | `fontSize13` | なし |
| READYラベル, subtitle | 14px | `fontSize14` | なし |
| ボタン, display name | 16px | `fontSize16` | なし |
| セクションタイトル, 接続ステータス | 18px | `fontSize18` | なし |
| カウントバッジ, ログアウト | 20px | `fontSize20` | なし |
| 設定項目値, sound option | 22px | `fontSize22` | なし |
| セクションヘッダ, ログインタイトル | 24px | `fontSize24` | なし |
| 設定項目タイトル | 26px | `fontSize26` | なし |
| 画面タイトル | 32px | `fontSize32` | なし |
| 注文番号, カラムタイトル | 48px | `fontSize48` | なし |

---

## 4. レイアウト定数

### 作成ファイル: `lib/core/theme/app_layout.dart`

画面固有のレイアウト定数を集約します。全て現在値をそのまま使用します。

```dart
/// OSD用レイアウト定数
/// 値: OSD現在値をそのまま保持
class OsdLayout {
  OsdLayout._();

  // === 注文ステータス画面: グリッド ===
  /// グリッド列数 (3列固定)
  static const int gridColumns = 3;

  /// カードのアスペクト比
  static const double cardAspectRatio = 2.0;

  /// ハイライトカードのアスペクト比 (単独)
  static const double highlightedCardAspectRatioSingle = 2.5;

  /// ハイライトカードのアスペクト比 (複数)
  static const double highlightedCardAspectRatioMultiple = 1.5;

  /// グリッド間隔
  static const double gridSpacing = 6;

  /// グリッドパディング
  static const double gridPadding = 8;

  // === 注文ステータス画面: カード ===
  /// カードパディング (通常)
  static const double cardPaddingH = 12;
  static const double cardPaddingV = 6;

  /// カードパディング (ハイライト)
  static const double cardHighlightedPaddingH = 16;
  static const double cardHighlightedPaddingV = 12;

  /// カードボーダー幅 (通常)
  static const double cardBorderWidth = 2;

  /// カードボーダー幅 (ハイライト)
  static const double cardHighlightedBorderWidth = 3;

  /// カード内 call number と elapsed time の flex 比率
  static const int cardCallNumberFlex = 3;
  static const int cardElapsedTimeFlex = 2;

  // === 注文ステータス画面: 2カラムレイアウト ===
  /// メイン画面の2カラム分割 (調理中 | 完了) — 等幅
  static const int mainColumnFlex = 1;

  /// カラム間仕切り幅
  static const double columnDividerWidth = 2;

  /// カラムヘッダパディング
  static const double headerPaddingV = 12;
  static const double headerPaddingH = 20;

  // === 注文ステータス画面: 接続ステータス ===
  /// 接続インジケータドットサイズ
  static const double connectionDotSize = 12;

  /// 接続ステータスバードットサイズ (connection_status_bar)
  static const double connectionBarDotSize = 8;

  // === 設定画面 ===
  /// AppBarツールバー高さ
  static const double settingsAppBarHeight = 80;

  /// 設定リストパディング
  static const double settingsListPadding = 24;

  /// 設定セクション間隔
  static const double settingsSectionGap = 24;

  /// 設定カードパディング
  static const double settingsCardPadding = 20;

  /// 設定カード margin bottom
  static const double settingsCardMarginBottom = 12;

  /// ダイアログ最大幅
  static const double dialogMaxWidth = 450;

  /// ダイアログ最大高さ
  static const double dialogMaxHeight = 500;

  /// ダイアログパディング
  static const double dialogPadding = 24;

  // === ログイン画面 ===
  /// ワイドスクリーンブレークポイント (>700px で2カラム)
  static const double loginWideBreakpoint = 700;

  /// 2カラムレイアウト最大幅
  static const double loginTwoColumnMaxWidth = 800;

  /// 1カラムレイアウト最大幅
  static const double loginSingleColumnMaxWidth = 400;

  /// ログインカードパディング
  static const double loginCardPadding = 24;

  /// ログインアプリロゴサイズ
  static const double loginLogoSize = 100;

  // === セットアップ画面 ===
  /// コンテンツ最大幅
  static const double setupMaxWidth = 500;

  /// ボディパディング
  static const double setupBodyPadding = 32;

  /// ヘッダパディング
  static const double setupHeaderPadding = 28;

  /// ステップドットサイズ
  static const double setupStepDotSize = 40;

  /// ステップコネクタ幅
  static const double setupStepConnectorWidth = 60;

  /// ボタン高さ
  static const double setupButtonHeight = 50;

  // === スプラッシュ画面 ===
  /// アプリアイコンサイズ
  static const double splashIconSize = 120;

  /// プログレスインジケータサイズ
  static const double splashProgressSize = 40;

  /// プログレスストローク幅
  static const double splashProgressStrokeWidth = 3;

  // === 共通: ボタン ===
  /// 標準ボタン高さ (ログイン画面)
  static const double buttonHeight = 48;

  // === 共通: 入力フィールド ===
  /// フォーカス時ボーダー幅
  static const double inputFocusBorderWidth = 2;

  // === 空状態 ===
  /// 空状態アイコン (注文ステータス画面)
  static const double emptyStateIconLarge = 144;

  /// 空状態アイコン (ディスプレイ選択画面)
  static const double emptyStateIconSmall = 80;

  // === ディスプレイ選択画面 ===
  /// ディスプレイアイコンコンテナサイズ
  static const double displayIconContainerSize = 56;
}
```

---

## 5. エレベーション

### 同ファイルに定義: `lib/core/theme/app_spacing.dart`

```dart
/// OSD用エレベーション定義 (BOS準拠)
class OsdElevation {
  OsdElevation._();

  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 2;   // AppBar, ボタン, ディスプレイカード
  static const double level3 = 3;
  static const double level4 = 4;   // CardTheme
  static const double level5 = 5;
}
```

### 現在のOSD値との対応

| 使用箇所 | 現在値 | 新定数 | 値の変更 |
|---------|--------|--------|---------|
| CardTheme elevation | 4 | `OsdElevation.level4` | なし |
| ボタン elevation | 2 | `OsdElevation.level2` | なし |
| ディスプレイカード elevation | 2 | `OsdElevation.level2` | なし |
| AppBar elevation | 2 | `OsdElevation.level2` | なし |

---

## 6. アニメーション

### 同ファイルに定義: `lib/core/theme/app_spacing.dart`

```dart
/// OSD用アニメーション定義
class OsdDurations {
  OsdDurations._();

  // === 汎用 (BOS準拠) ===
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration long = Duration(milliseconds: 500);
  static const Duration extraLong = Duration(milliseconds: 1000);

  // === OSD固有 ===
  /// パルスアニメーション周期 (ハイライトカード)
  static const Duration pulse = Duration(milliseconds: 1000);

  /// カーソル非表示までの時間
  static const Duration cursorHide = Duration(seconds: 3);

  /// カード更新タイマー間隔
  static const Duration cardUpdateInterval = Duration(seconds: 30);
}

/// OSD固有アニメーション値
class OsdAnimations {
  OsdAnimations._();

  /// パルスアニメーション開始スケール
  static const double pulseScaleStart = 1.0;

  /// パルスアニメーション終了スケール
  static const double pulseScaleEnd = 1.05;
}
```

---

## 7. アイコンサイズ

### 作成ファイル: `lib/core/theme/app_icons.dart`

```dart
/// OSD用アイコンサイズ定義
/// 値: OSD現在値をそのまま保持
class OsdIconSizes {
  OsdIconSizes._();

  static const double size12 = 12;   // ステータスドット
  static const double size14 = 14;   // カテゴリアイコン (display_selection)
  static const double size16 = 16;   // 警告アイコン, 接続ステータス
  static const double size20 = 20;   // 設定ボタン, エラー, email/google, ボタン内
  static const double size24 = 24;   // WiFi, ストア, ステップドットチェック, feature
  static const double size28 = 28;   // ログアウト, サウンドオプション, チェックマーク, ディスプレイカード内
  static const double size32 = 32;   // 表示タイプ, 戻るボタン
}
```

---

## 8. ファイル構成

### 新規作成ファイル一覧

```
lib/
└── core/
    └── theme/
        ├── app_spacing.dart      ← OsdSpacing + OsdRadius + OsdElevation + OsdDurations + OsdAnimations
        ├── app_typography.dart   ← OsdTypography
        ├── app_layout.dart       ← OsdLayout
        └── app_icons.dart        ← OsdIconSizes
```

**注:** レスポンシブ関連ファイル (`responsive/`) は作成しません。現在のOSDは固定レイアウトであり、その動作を維持します。

---

## 9. 変更対象ファイルと修正内容

全てのマッピングで値の変更はありません。ハードコード値を同一値の定数名に置き換えるのみです。

### 9.1 `lib/main.dart`

| 現在値 | 新定数 | 値の変更 |
|--------|--------|---------|
| `elevation: 4` (CardTheme) | `OsdElevation.level4` | なし |
| `margin: EdgeInsets.all(8)` | `EdgeInsets.all(OsdSpacing.space8)` | なし |
| `borderRadius: 16` (CardTheme) | `OsdRadius.lg` | なし |
| `elevation: 2` (ElevatedButton) | `OsdElevation.level2` | なし |
| `borderRadius: 12` (ElevatedButton) | `OsdRadius.md` | なし |
| `width: 120, height: 120` (アプリアイコン) | `OsdLayout.splashIconSize` | なし |
| `fontSize: 32` (アプリ名) | `OsdTypography.fontSize32` | なし |
| `fontSize: 16` (サブタイトル) | `OsdTypography.fontSize16` | なし |
| `SizedBox(height: 48)` | `SizedBox(height: OsdSpacing.space48)` | なし |
| `width: 40, height: 40` (プログレス) | `OsdLayout.splashProgressSize` | なし |
| `strokeWidth: 3` | `OsdLayout.splashProgressStrokeWidth` | なし |

### 9.2 `lib/screens/order_status_screen.dart`

| 現在値 | 新定数 | 値の変更 |
|--------|--------|---------|
| `Duration(milliseconds: 1000)` | `OsdDurations.pulse` | なし |
| `width: 12, height: 12` (ドット) | `OsdIconSizes.size12` / `OsdLayout.connectionDotSize` | なし |
| `padding: 8` (設定ボタン) | `OsdSpacing.space8` | なし |
| `size: 20` (設定アイコン) | `OsdIconSizes.size20` | なし |
| `borderRadius: 20` (接続インジケータ) | `OsdRadius.xl` | なし |
| `padding: V12, H20` (ヘッダ) | `OsdLayout.headerPaddingV/H` | なし |
| `fontSize: 48` (タイトル) | `OsdTypography.fontSize48` | なし |
| `padding: H14, V6` (バッジ) | `OsdSpacing.space14`, `OsdSpacing.space6` | なし |
| `borderRadius: 16` (バッジ) | `OsdRadius.lg` | なし |
| `fontSize: 20` (バッジ) | `OsdTypography.fontSize20` | なし |
| `size: 144` (空状態アイコン) | `OsdLayout.emptyStateIconLarge` | なし |
| `fontSize: 48` (空状態) | `OsdTypography.fontSize48` | なし |
| `padding: 8` (グリッド) | `OsdLayout.gridPadding` | なし |
| `crossAxisCount: 3` | `OsdLayout.gridColumns` | なし |
| `childAspectRatio: 2.0` | `OsdLayout.cardAspectRatio` | なし |
| `crossAxisSpacing: 6` | `OsdLayout.gridSpacing` | なし |
| `mainAxisSpacing: 6` | `OsdLayout.gridSpacing` | なし |
| `aspectRatio: 2.5` (HL単独) | `OsdLayout.highlightedCardAspectRatioSingle` | なし |
| `aspectRatio: 1.5` (HL複数) | `OsdLayout.highlightedCardAspectRatioMultiple` | なし |
| `fontSize: 12` (dividerラベル) | `OsdTypography.fontSize12` | なし |
| `size: 16` (警告アイコン) | `OsdIconSizes.size16` | なし |

### 9.3 `lib/widgets/order_card.dart`

| 現在値 | 新定数 | 値の変更 |
|--------|--------|---------|
| `Duration(milliseconds: 1000)` | `OsdDurations.pulse` | なし |
| `1.0` ~ `1.05` (スケール) | `OsdAnimations.pulseScaleStart/End` | なし |
| `Duration(seconds: 30)` | `OsdDurations.cardUpdateInterval` | なし |
| `2.0` / `3.0` (ボーダー幅) | `OsdLayout.cardBorderWidth/cardHighlightedBorderWidth` | なし |
| `padding: H12, V6` (通常) | `OsdLayout.cardPaddingH/V` | なし |
| `padding: H16, V12` (HL) | `OsdLayout.cardHighlightedPaddingH/V` | なし |
| `borderRadius: 12` (通常) | `OsdRadius.md` | なし |
| `borderRadius: 16` (HL) | `OsdRadius.lg` | なし |
| `padding: H12, V4` (READYラベル) | `OsdSpacing.space12`, `OsdSpacing.space4` | なし |
| `borderRadius: 12` (READYラベル) | `OsdRadius.md` | なし |
| `fontSize: 14` (READYラベル) | `OsdTypography.fontSize14` | なし |
| `letterSpacing: 1` | `OsdTypography.letterSpacing1` | なし |
| `fontSize: 48` (注文番号) | `OsdTypography.fontSize48` | なし |
| `letterSpacing: 1` (注文番号) | `OsdTypography.letterSpacing1` | なし |
| `letterSpacing: 2` (HL注文番号) | `OsdTypography.letterSpacing2` | なし |
| `flex: 3` (注文番号) | `OsdLayout.cardCallNumberFlex` | なし |
| `flex: 2` (elapsed time) | `OsdLayout.cardElapsedTimeFlex` | なし |
| `padding: H8, V2` (elapsed time) | `OsdSpacing.space8`, `OsdSpacing.space2` | なし |
| `borderRadius: 8` (elapsed time) | `OsdRadius.base` | なし |
| `fontSize: 12` (elapsed time) | `OsdTypography.fontSize12` | なし |

### 9.4 `lib/screens/login_screen.dart`

| 現在値 | 新定数 | 値の変更 |
|--------|--------|---------|
| `screenWidth > 700` | `OsdLayout.loginWideBreakpoint` | なし |
| `width: 100, height: 100` (ロゴ) | `OsdLayout.loginLogoSize` | なし |
| `fontSize: 24` (タイトル) | `OsdTypography.fontSize24` | なし |
| `fontSize: 14` (サブタイトル) | `OsdTypography.fontSize14` | なし |
| `maxWidth: 800` (2列) | `OsdLayout.loginTwoColumnMaxWidth` | なし |
| `maxWidth: 400` (1列) | `OsdLayout.loginSingleColumnMaxWidth` | なし |
| `padding: 24` (カード) | `OsdLayout.loginCardPadding` | なし |
| `borderRadius: 16` (カード) | `OsdRadius.lg` | なし |
| `fontSize: 18` (セクションタイトル) | `OsdTypography.fontSize18` | なし |
| `borderRadius: 8` (入力) | `OsdRadius.base` | なし |
| `height: 48` (ボタン) | `OsdLayout.buttonHeight` | なし |
| `borderRadius: 16` (ボタン) | `OsdRadius.lg` | なし |
| `fontSize: 16` (ボタン) | `OsdTypography.fontSize16` | なし |
| `fontSize: 12` (フッタ) | `OsdTypography.fontSize12` | なし |
| `fontSize: 14` (or divider) | `OsdTypography.fontSize14` | なし |
| `fontSize: 13` (description) | `OsdTypography.fontSize13` | なし |
| `borderRadius: 8` (error) | `OsdRadius.base` | なし |
| `fontSize: 14` (error) | `OsdTypography.fontSize14` | なし |

### 9.5 `lib/screens/settings_screen.dart`

| 現在値 | 新定数 | 値の変更 |
|--------|--------|---------|
| `toolbarHeight: 80` | `OsdLayout.settingsAppBarHeight` | なし |
| `fontSize: 32` (タイトル) | `OsdTypography.fontSize32` | なし |
| `size: 32` (戻るボタン) | `OsdIconSizes.size32` | なし |
| `size: 24` (WiFi) | `OsdIconSizes.size24` | なし |
| `fontSize: 18` (接続ステータス) | `OsdTypography.fontSize18` | なし |
| `size: 28` (ログアウト) | `OsdIconSizes.size28` | なし |
| `fontSize: 20` (ログアウトtext) | `OsdTypography.fontSize20` | なし |
| `padding: 24` (リスト) | `OsdLayout.settingsListPadding` | なし |
| `fontSize: 24` (セクションヘッダ) | `OsdTypography.fontSize24` | なし |
| `letterSpacing: 1.5` | `OsdTypography.letterSpacing15` | なし |
| `fontSize: 22` (info value) | `OsdTypography.fontSize22` | なし |
| `fontSize: 26` (スイッチタイトル) | `OsdTypography.fontSize26` | なし |
| `fontSize: 18` (subtitle) | `OsdTypography.fontSize18` | なし |
| `fontSize: 24` (percentage) | `OsdTypography.fontSize24` | なし |
| `fontSize: 22` (sound option) | `OsdTypography.fontSize22` | なし |
| `fontSize: 20` (duration option) | `OsdTypography.fontSize20` | なし |
| `borderRadius: 16` (カード) | `OsdRadius.lg` | なし |
| `borderRadius: 12` (option) | `OsdRadius.md` | なし |
| `borderRadius: 10` (duration) | `OsdRadius.r10` | なし |
| `margin: 12` (カード) | `OsdLayout.settingsCardMarginBottom` | なし |
| `padding: 20` (カード) | `OsdLayout.settingsCardPadding` | なし |
| `maxWidth: 450` (ダイアログ) | `OsdLayout.dialogMaxWidth` | なし |
| `maxHeight: 500` (ダイアログ) | `OsdLayout.dialogMaxHeight` | なし |
| `padding: 24` (ダイアログ) | `OsdLayout.dialogPadding` | なし |
| `borderRadius: 12` (ダイアログ入力) | `OsdRadius.md` | なし |

### 9.6 `lib/screens/display_selection_screen.dart`

| 現在値 | 新定数 | 値の変更 |
|--------|--------|---------|
| `elevation: 2` (AppBar) | `OsdElevation.level2` | なし |
| `size: 80` (空状態アイコン) | `OsdLayout.emptyStateIconSmall` | なし |
| `fontSize: 20` (空状態タイトル) | `OsdTypography.fontSize20` | なし |
| `fontSize: 14` (空状態subtitle) | `OsdTypography.fontSize14` | なし |
| `fontSize: 24` (選択タイトル) | `OsdTypography.fontSize24` | なし |
| `fontSize: 12` (メールバッジ) | `OsdTypography.fontSize12` | なし |
| `fontSize: 16` (ストア名) | `OsdTypography.fontSize16` | なし |
| `elevation: 2` (カード) | `OsdElevation.level2` | なし |
| `borderRadius: 12` (カード) | `OsdRadius.md` | なし |
| `width: 56, height: 56` (アイコン) | `OsdLayout.displayIconContainerSize` | なし |
| `borderRadius: 12` (アイコンBG) | `OsdRadius.md` | なし |
| `size: 28` (アイコン) | `OsdIconSizes.size28` | なし |
| `fontSize: 16` (display name) | `OsdTypography.fontSize16` | なし |
| `fontSize: 10` (DEFAULTバッジ) | `OsdTypography.fontSize10` | なし |
| `letterSpacing: 0.5` | `OsdTypography.letterSpacing05` | なし |
| `borderRadius: 4` (バッジ) | `OsdRadius.sm` | なし |
| `size: 14` (カテゴリアイコン) | `OsdIconSizes.size14` | なし |
| `fontSize: 13` (カテゴリテキスト) | `OsdTypography.fontSize13` | なし |
| `fontSize: 11` (チップ) | `OsdTypography.fontSize11` | なし |
| `borderRadius: 6` (チップ) | `OsdRadius.xs` | なし |

### 9.7 `lib/widgets/connection_status_bar.dart`

| 現在値 | 新定数 | 値の変更 |
|--------|--------|---------|
| `padding: H16, V8` | `OsdSpacing.space16`, `OsdSpacing.space8` | なし |
| `size: 16` (アイコン) | `OsdIconSizes.size16` | なし |
| `fontSize: 12` | `OsdTypography.fontSize12` | なし |
| `borderRadius: 16` | `OsdRadius.lg` | なし |
| `dot: 8x8` | `OsdLayout.connectionBarDotSize` | なし |
| `padding: H12, V6` | `OsdSpacing.space12`, `OsdSpacing.space6` | なし |

### 9.8 `lib/screens/initial_setup_screen.dart`

| 現在値 | 新定数 | 値の変更 |
|--------|--------|---------|
| `padding: 32` (全体) | `OsdLayout.setupBodyPadding` | なし |
| `maxWidth: 500` | `OsdLayout.setupMaxWidth` | なし |
| `padding: 28` (ヘッダ) | `OsdLayout.setupHeaderPadding` | なし |
| `borderRadius: 24` (ヘッダ) | `OsdRadius.xxl` | なし |
| `size: 72` (ヘッダアイコン) | 画面固有: 定数化しない or `OsdLayout` に追加 | なし |
| `fontSize: 32` (タイトル) | `OsdTypography.fontSize32` | なし |
| `fontSize: 16` (サブタイトル) | `OsdTypography.fontSize16` | なし |
| `size: 40x40` (ステップドット) | `OsdLayout.setupStepDotSize` | なし |
| `size: 24` (チェックアイコン) | `OsdIconSizes.size24` | なし |
| `fontSize: 18` (ステップテキスト) | `OsdTypography.fontSize18` | なし |
| `fontSize: 14` (ステップラベル) | `OsdTypography.fontSize14` | なし |
| `width: 60` (コネクタ) | `OsdLayout.setupStepConnectorWidth` | なし |
| `borderRadius: 16` (カード) | `OsdRadius.lg` | なし |
| `fontSize: 22` (見出し) | `OsdTypography.fontSize22` | なし |
| `height: 50` (ボタン) | `OsdLayout.setupButtonHeight` | なし |
| `borderRadius: 12` (ボタン) | `OsdRadius.md` | なし |
| `fontSize: 18` (ボタンtext) | `OsdTypography.fontSize18` | なし |
| `borderRadius: 8` (エラー) | `OsdRadius.base` | なし |
| `borderRadius: 12` (入力) | `OsdRadius.md` | なし |

---

## 10. 実装手順

### Phase 1: 定数ファイル作成

1. `lib/core/theme/app_spacing.dart` — OsdSpacing + OsdRadius + OsdElevation + OsdDurations + OsdAnimations
2. `lib/core/theme/app_typography.dart` — OsdTypography
3. `lib/core/theme/app_layout.dart` — OsdLayout
4. `lib/core/theme/app_icons.dart` — OsdIconSizes

### Phase 2: メイン表示画面の定数置換

5. `lib/widgets/order_card.dart`
6. `lib/screens/order_status_screen.dart`

### Phase 3: 認証・設定画面の定数置換

7. `lib/screens/login_screen.dart`
8. `lib/screens/settings_screen.dart`
9. `lib/screens/display_selection_screen.dart`

### Phase 4: その他の定数置換

10. `lib/main.dart`
11. `lib/widgets/connection_status_bar.dart`
12. `lib/screens/initial_setup_screen.dart`

### 各Phaseの検証

- Phase毎にビルド確認を行い、画面表示が変わらないことを目視確認する
- 特にPhase 2ではメイン画面の3列グリッド、カードサイズ、フォントサイズが完全に同一であることを確認する

---

## 11. BOSとの関係

| OSDファイル | BOSとの関係 | 説明 |
|------------|-----------|------|
| `app_spacing.dart` | **命名規則のみ参考** | BOSは6px刻み、OSDは実使用値ベース |
| `app_typography.dart` | **命名規則のみ参考** | BOSは14px開始、OSDは10px開始 |
| `app_layout.dart` | **OSD独自** | OSD固有のレイアウト定数 |
| `app_icons.dart` | **OSD独自** | OSD固有のアイコンサイズ |

**共通化しない理由:**
- BOSの6px刻みスペーシングはOSDの4/8pxベースと合わない
- BOSのフォントサイズスケール (14px〜) はOSDの小サイズ (10-13px) をカバーしない
- 無理に合わせると現在の表示が崩れるため、各アプリで独立した定数体系を持つ

---

## 12. 現状維持する動作の明記

以下の動作は本作業では変更しません。

| 動作 | 現状 | 変更 |
|------|------|------|
| グリッド列数 | 3列固定 (`crossAxisCount: 3`) | なし |
| カードアスペクト比 | 2.0固定 | なし |
| フォントサイズ | 全画面で固定値 | なし |
| レスポンシブ対応 | ログイン画面のみ (700px breakpoint) | なし |
| テキストスケーリング | FittedBox (scaleDown) のみ | なし |
| 画面向き対応 | なし | なし |
