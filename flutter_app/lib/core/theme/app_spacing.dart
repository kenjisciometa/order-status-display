import 'package:flutter/material.dart';

/// OSD用スペーシング定義
/// 命名規則: BOSベース (order_sys/bos/flutter_app/lib/core/theme/app_spacing.dart)
/// 値: OSD現在値をそのまま保持
class OsdSpacing {
  OsdSpacing._();

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

/// OSD用角丸定義
/// BOS準拠 + OSD固有値 (xs=6, r10=10) を追加
class OsdRadius {
  OsdRadius._();

  static const double none = 0;
  static const double sm = 4;
  static const double xs = 6;
  static const double base = 8;
  static const double r10 = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 9999;

  // BorderRadius helpers
  static BorderRadius get borderRadiusSm => BorderRadius.circular(sm);
  static BorderRadius get borderRadiusXs => BorderRadius.circular(xs);
  static BorderRadius get borderRadiusBase => BorderRadius.circular(base);
  static BorderRadius get borderRadiusR10 => BorderRadius.circular(r10);
  static BorderRadius get borderRadiusMd => BorderRadius.circular(md);
  static BorderRadius get borderRadiusLg => BorderRadius.circular(lg);
  static BorderRadius get borderRadiusXl => BorderRadius.circular(xl);
  static BorderRadius get borderRadiusXxl => BorderRadius.circular(xxl);
}

/// OSD用エレベーション定義 (BOS準拠)
class OsdElevation {
  OsdElevation._();

  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 2;
  static const double level3 = 3;
  static const double level4 = 4;
  static const double level5 = 5;
}

/// OSD用アニメーション duration 定義
class OsdDurations {
  OsdDurations._();

  // 汎用 (BOS準拠)
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration long = Duration(milliseconds: 500);
  static const Duration extraLong = Duration(milliseconds: 1000);

  // OSD固有
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
