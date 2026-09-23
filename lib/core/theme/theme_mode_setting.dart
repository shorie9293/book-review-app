import 'package:flutter/material.dart';

/// テーマ設定（ライト／ダーク／システム）
enum ThemeModeSetting {
  light('light', 'ライト'),
  dark('dark', 'ダーク'),
  system('system', 'システム');

  const ThemeModeSetting(this.storageKey, this.label);

  /// 永続化用のキー文字列
  final String storageKey;

  /// 表示用ラベル
  final String label;

  /// 表示用アイコン
  IconData get icon => switch (this) {
        ThemeModeSetting.light => Icons.light_mode,
        ThemeModeSetting.dark => Icons.dark_mode,
        ThemeModeSetting.system => Icons.brightness_auto,
      };

  /// 保存キーから復元する。不明値 / null は system。
  static ThemeModeSetting fromStorageKey(String? key) {
    for (final mode in ThemeModeSetting.values) {
      if (mode.storageKey == key) return mode;
    }
    return ThemeModeSetting.system;
  }

  /// light → dark → system → light の巡回。
  ThemeModeSetting get next => switch (this) {
        ThemeModeSetting.light => ThemeModeSetting.dark,
        ThemeModeSetting.dark => ThemeModeSetting.system,
        ThemeModeSetting.system => ThemeModeSetting.light,
      };

  /// MaterialApp の themeMode へ変換する。
  ThemeMode toThemeMode() => switch (this) {
        ThemeModeSetting.light => ThemeMode.light,
        ThemeModeSetting.dark => ThemeMode.dark,
        ThemeModeSetting.system => ThemeMode.system,
      };
}