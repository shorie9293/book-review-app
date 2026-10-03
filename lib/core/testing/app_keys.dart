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

  /// 蔵書詳細: 進行ページ更新の導線（読書中のみ表示）
  static const Key bookProgressEdit = Key('book_progress_edit');

  /// 蔵書詳細: 進行ページ入力欄（ダイアログ内）
  static const Key bookProgressInput = Key('book_progress_input');

  /// 蔵書詳細: 進行ページの保存ボタン（ダイアログ内）
  static const Key bookProgressSave = Key('book_progress_save');

  /// 蔵書詳細: 読書開始ボタン（未読の本のみ表示）
  static const Key bookProgressStart = Key('book_progress_start');

  /// 蔵書詳細: ジャンル追加ボタン
  static const Key genreAdd = Key('genre_add');

  /// 蔵書詳細: ジャンル追加ダイアログ
  static const Key genreDialog = Key('genre_dialog');

  /// 蔵書詳細: ジャンル入力欄（ダイアログ内）
  static const Key genreInput = Key('genre_input');

  /// 蔵書詳細: ジャンル保存ボタン（ダイアログ内）
  static const Key genreSave = Key('genre_save');

  /// 蔵書詳細: 指定ジャンルのチップ表示
  static Key genreChip(String genre) => Key('genre_chip_$genre');

  /// 蔵書詳細: 指定ジャンルの削除導線
  static Key genreRemove(String genre) => Key('genre_remove_$genre');

  /// 本棚: 指定ジャンルの絞り込みチップ
  static Key genreFilterChip(String genre) => Key('library_genre_chip_$genre');

  /// 停滞本一覧: 件数ラベル
  static const Key stagnantCountLabel = Key('stagnant_count_label');

  /// 停滞本一覧: 指定本のエントリ行
  static Key stagnantEntry(String bookId) => Key('stagnant_entry_$bookId');

  /// 停滞本一覧: 指定本の経過日数表示
  static Key stagnantDays(String bookId) => Key('stagnant_days_$bookId');

  /// 停滞本一覧: 停滞理由の絞り込みチップ（enum名を指定）
  static Key stagnantReasonChip(String reason) => Key('stagnant_reason_chip_$reason');

  /// 停滞本一覧: 閾値日数の選択チップ
  static Key stagnantMinChip(int days) => Key('stagnant_min_chip_$days');

  /// 停滞本一覧: 検索欄
  static const Key stagnantSearchField = Key('stagnant_search_field');

  /// 停滞本一覧: 検索クリアボタン
  static const Key stagnantSearchClear = Key('stagnant_search_clear');

  /// 停滞本一覧: 空状態
  static const Key stagnantEmpty = Key('stagnant_empty');
}