import 'package:flutter/material.dart';

/// OSD用タイポグラフィ定義
/// 命名規則: BOSベース (order_sys/bos/flutter_app/lib/core/theme/app_typography.dart)
/// 値: OSD現在値をそのまま保持
class OsdTypography {
  OsdTypography._();

  // === フォントサイズ (OSDで使用されている全値) ===
  static const double fontSize10 = 10; // DEFAULTバッジ
  static const double fontSize11 = 11; // カテゴリチップ
  static const double fontSize12 = 12; // elapsed time, dividerラベル, メールバッジ
  static const double fontSize13 = 13; // カテゴリテキスト, description
  static const double fontSize14 = 14; // READYラベル, subtitle, エラー, step label
  static const double fontSize16 = 16; // ボタン, display name, ストア名
  static const double fontSize18 = 18; // セクションタイトル, 接続ステータス
  static const double fontSize20 = 20; // カウントバッジ, ログアウト, duration option
  static const double fontSize22 = 22; // 設定項目値, sound option
  static const double fontSize24 = 24; // セクションヘッダ, ログインタイトル
  static const double fontSize26 = 26; // 設定項目タイトル, スイッチタイトル
  static const double fontSize32 = 32; // 画面タイトル (設定, スプラッシュ)
  static const double fontSize48 = 48; // 注文番号, カラムタイトル, 空状態メッセージ

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
  static const double letterSpacing05 = 0.5; // DEFAULTバッジ
  static const double letterSpacing1 = 1; // READYラベル, 注文番号
  static const double letterSpacing15 = 1.5; // セクションヘッダ
  static const double letterSpacing2 = 2; // ハイライト注文番号
}
