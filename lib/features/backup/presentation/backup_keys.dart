import 'package:flutter/material.dart';

/// バックアップ画面の試練（テスト）用 Key の一元管理。
class BackupKeys {
  const BackupKeys._();

  /// サマリー（件数）カード
  static const Key summaryCard = Key('backup_summary_card');

  /// 「エクスポート」ボタン（JSON プレビュー生成）
  static const Key exportButton = Key('backup_export_button');

  /// JSON コピーボタン
  static const Key copyButton = Key('backup_copy_button');

  /// CSV エクスポートボタン
  static const Key csvExportButton = Key('backup_csv_export_button');

  /// 復元用 JSON 貼り付けフィールド
  static const Key importField = Key('backup_import_field');

  /// 「復元」ボタン
  static const Key restoreButton = Key('backup_restore_button');

  /// 復元確認ダイアログの「復元する」ボタン
  static const Key confirmRestoreButton = Key('backup_confirm_restore_button');

  /// JSON プレビュー表示
  static const Key jsonPreview = Key('backup_json_preview');

  /// エラー表示
  static const Key errorText = Key('backup_error_text');

  /// 画面（Scaffold）
  static const Key screen = Key('backup_screen');
}
