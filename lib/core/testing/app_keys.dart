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

  /// チュートリアル画面のルート
  static const Key tutorialScreen = Key('screen_tutorial');

  /// チュートリアル: 次へ/はじめるボタン
  static const Key tutorialNext = Key('tutorial_next_button');

  /// チュートリアル: スキップボタン
  static const Key tutorialSkip = Key('tutorial_skip_button');

  /// チュートリアル: ページインジケータ
  static const Key tutorialIndicator = Key('tutorial_page_indicator');

  /// チュートリアル: 指定ページの本文
  static Key tutorialPage(String keyName) => Key(keyName);

  /// 読書時間画面への導線（書庫 AppBar）
  static const Key readingTimerButton = Key('reading_timer_button');

  /// 読書時間: 開始ボタン
  static const Key readingStart = Key('reading_start_button');

  /// 読書時間: 停止/保存ボタン
  static const Key readingStop = Key('reading_stop_button');

  /// 読書時間: 経過表示
  static const Key readingElapsed = Key('reading_elapsed_label');

  /// 読書時間: 総読書時間の統計ラベル
  static const Key readingTotalLabel = Key('reading_total_label');

  /// 読書時間: 手動追加ボタン
  static const Key readingAddButton = Key('reading_add_button');

  /// 読書時間: セッション行
  static Key readingSessionRow(String id) => Key('reading_session_$id');

  /// 読書時間: 空状態
  static const Key readingEmpty = Key('reading_empty');

  /// 読書の推薦画面（Scaffold）
  static const Key recommendationScreen = Key('screen_recommendation');

  /// 読書の推薦: ローディング状態
  static const Key recommendationLoading = Key('recommendation_loading');

  /// 読書の推薦: 空状態
  static const Key recommendationEmpty = Key('recommendation_empty');

  /// 読書の推薦: 指定本のカード
  static Key recommendationCard(String bookId) =>
      Key('recommendation_card_$bookId');

  /// 読了予測画面（Scaffold）
  static const Key finishForecastScreen = Key('screen_finish_forecast');

  /// 読了予測: ローディング状態
  static const Key finishForecastLoading = Key('finish_forecast_loading');

  /// 読了予測: 空状態
  static const Key finishForecastEmpty = Key('finish_forecast_empty');

  /// 読了予測: 指定本のカード
  static Key finishForecastCard(String bookId) =>
      Key('finish_forecast_card_$bookId');

  /// 読了予測画面への導線（統計 AppBar アクション）
  static const Key finishForecastOpenButton = Key('finish_forecast_open_button');

  /// 統計: 前年比カード
  static const Key statsYearComparison = Key('stats_year_comparison');

  /// 統計: 前年比 読了冊数ラベル
  static const Key statsComparisonFinished = Key('stats_comparison_finished');

  /// 統計: 前年比 ページ数ラベル
  static const Key statsComparisonPages = Key('stats_comparison_pages');

  /// 統計: 前年比 著者数ラベル
  static const Key statsComparisonAuthors = Key('stats_comparison_authors');

  /// 読書習慣ヒートマップ: 全体Container
  static const Key readingHabitHeatmap = Key('reading_habit_heatmap');

  /// 読書習慣ヒートマップ: 集計行（busiestラベル・合計）
  static const Key readingHabitBusiest = Key('reading_habit_busiest');

  /// 読書習慣ヒートマップ: 空メッセージ
  static const Key readingHabitEmpty = Key('reading_habit_empty');

  /// 読書習慣ヒートマップ: グリッド
  static const Key readingHabitGrid = Key('reading_habit_grid');

  /// 読書習慣ヒートマップ: 各セル（weekday: 1..7, slot: 0..5）
  static Key readingHabitCell(int weekday, int slot) =>
      Key('reading_habit_cell_${weekday}_$slot');

  /// 読書習慣ヒートマップ: 凡例
  static const Key readingHabitLegend = Key('reading_habit_legend');

  /// 読書リマインダー設定画面（Scaffold）
  static const Key readingReminderScreen = Key('reading_reminder_screen');

  /// 読書リマインダー: 有効スイッチ
  static const Key readingReminderEnabledSwitch =
      Key('reading_reminder_enabled_switch');

  /// 読書リマインダー: 通知時刻ボタン
  static const Key readingReminderTimeButton =
      Key('reading_reminder_time_button');

  /// 読書リマインダー: 保存ボタン
  static const Key readingReminderSaveButton =
      Key('reading_reminder_save_button');

  /// 読書リマインダー: テスト通知ボタン
  static const Key readingReminderTestButton =
      Key('reading_reminder_test_button');

  /// 読書リマインダー: 次回通知ラベル
  static const Key readingReminderNextLabel =
      Key('reading_reminder_next_label');

  /// 読書リマインダー画面への導線（本棚 AppBar）
  static const Key readingReminderEntry = Key('reading_reminder_entry');

  /// 読書リマインダー: 曜日選択チップ（weekday: 1..7）
  static Key readingReminderWeekdayChip(int weekday) =>
      Key('reading_reminder_weekday_$weekday');
}