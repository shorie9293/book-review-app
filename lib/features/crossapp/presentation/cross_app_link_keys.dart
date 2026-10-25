import 'package:flutter/material.dart';

/// クロスアプリ連携画面の試練（テスト）用 Key の一元管理。
///
/// 既存の `AppKeys` を汚さないため別ファイルに分離する。
class CrossAppLinkKeys {
  const CrossAppLinkKeys._();

  /// 画面（Scaffold）
  static const Key screen = Key('cross_app_link_screen');

  /// 連携コード（8文字）の表示
  static const Key linkCode = Key('cross_app_link_code');

  /// 「コピー」ボタン
  static const Key copyButton = Key('cross_app_link_copy');

  /// 送信済み読了イベント件数
  static const Key sentCount = Key('cross_app_link_sent_count');

  /// バックアップ画面からの導線
  static const Key entry = Key('cross_app_link_entry');
}
