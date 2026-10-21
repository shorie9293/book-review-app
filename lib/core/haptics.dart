import 'package:flutter/services.dart';

/// 主要操作の成功を触覚で伝える（軽いクリック）。
///
/// `flutter_test` ではプラットフォームチャネルが未解決で `await` が永久に
/// 完了しないため、**await せず** [Future.ignore] で投げっぱなしにする。
void hapticTap() {
  HapticFeedback.selectionClick().ignore();
}
