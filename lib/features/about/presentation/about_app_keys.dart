import 'package:flutter/material.dart';

/// 「アプリについて」画面の試練用Key（AppKeys の流儀に倣い一元管理）。
class AboutAppKeys {
  const AboutAppKeys._();

  /// 画面（Scaffold）
  static const Key screen = Key('about_screen');

  /// 本棚 AppBar からの導線
  static const Key entry = Key('about_entry');

  /// OSSライセンスボタン
  static const Key licenseButton = Key('about_license_button');

  /// プライバシーポリシーボタン
  static const Key privacyButton = Key('about_privacy_button');

  /// 問い合わせボタン
  static const Key contactButton = Key('about_contact_button');

  /// ダイアログ内のコピー系ボタン共通接頭辞（URL/メール）
  static const Key copyButton = Key('about_copy_button');
}
