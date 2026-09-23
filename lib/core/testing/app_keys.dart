import 'package:flutter/material.dart';

/// 試練（テスト）用 Key の一元管理（重複禁止）。
class AppKeys {
  const AppKeys._();

  /// テーマ設定画面（Scaffold）
  static const Key themeModeScreen = Key('theme_mode_screen');

  /// テーマ設定画面への導線（AppBar アクション）
  static const Key themeModeEntry = Key('theme_mode_entry');

  /// テーマ3択の各選択肢（'light' / 'dark' / 'system'）
  static Key themeModeOption(String storageKey) =>
      Key('theme_mode_option_$storageKey');
}