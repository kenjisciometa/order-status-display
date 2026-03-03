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
