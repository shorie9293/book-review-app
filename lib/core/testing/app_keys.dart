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

  /// 「動きを減らす」設定画面（Scaffold）
  static const Key reduceMotionScreen = Key('reduce_motion_screen');

  /// 「動きを減らす」設定画面への導線（本棚 AppBar アクション）
  static const Key reduceMotionEntry = Key('reduce_motion_entry');

  /// 「動きを減らす」3択の各選択肢（'system' / 'off' / 'on'）
  static Key reduceMotionOption(String storageKey) =>
      Key('reduce_motion_option_$storageKey');

  /// アプリロック設定画面（Scaffold）
  static const Key appLockScreen = Key('app_lock_screen');

  /// アプリロック設定画面への導線（本棚 AppBar アクション）
  static const Key appLockEntry = Key('app_lock_entry');

  /// アプリロックゲート: パスコード入力欄
  static const Key appLockGateField = Key('app_lock_gate_field');

  /// アプリロック: 新しいパスコード入力欄
  static const Key appLockPasscodeField = Key('app_lock_passcode_field');

  /// アプリロック: 確認用パスコード入力欄
  static const Key appLockConfirmField = Key('app_lock_confirm_field');

  /// アプリロック: 有効化ボタン
  static const Key appLockEnableButton = Key('app_lock_enable_button');

  /// アプリロック: 無効化ボタン
  static const Key appLockDisableButton = Key('app_lock_disable_button');

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

  /// 蔵書詳細: ジャンル入力欄
  static const Key genreInput = Key('genre_input');

  /// 蔵書詳細: ジャンル保存ボタン
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

  /// 静穏時間（おやすみモード）設定画面（Scaffold）
  static const Key quietHoursScreen = Key('quiet_hours_screen');

  /// 静穏時間設定画面への導線（読書リマインダー設定画面）
  static const Key quietHoursEntry = Key('quiet_hours_entry');

  /// 静穏時間: 有効スイッチ
  static const Key quietHoursToggle = Key('quiet_hours_toggle');

  /// 静穏時間: 開始時刻の「時」
  static const Key quietHoursStartHour = Key('quiet_hours_start_hour');

  /// 静穏時間: 開始時刻の「分」
  static const Key quietHoursStartMinute = Key('quiet_hours_start_minute');

  /// 静穏時間: 終了時刻の「時」
  static const Key quietHoursEndHour = Key('quiet_hours_end_hour');

  /// 静穏時間: 終了時刻の「分」
  static const Key quietHoursEndMinute = Key('quiet_hours_end_minute');

  /// 静穏時間: 静穏時間中の通知方針ラジオ（policy.storageKey を指定）
  static Key quietHoursPolicyRadio(String storageKey) =>
      Key('quiet_hours_policy_$storageKey');

  /// 静穏時間: 設定内容のプレビュー文言
  static const Key quietHoursPreview = Key('quiet_hours_preview');

  /// 静穏時間: 保存ボタン
  static const Key quietHoursSaveButton = Key('quiet_hours_save_button');

  /// 読書統計グラフ画面（Scaffold）
  static const Key readingTrendScreen = Key('reading_trend_screen');

  /// 読書統計グラフ画面への導線（統計 AppBar アクション）
  static const Key readingTrendEntry = Key('reading_trend_entry');

  /// 読書統計グラフ: ローディング状態
  static const Key readingTrendLoading = Key('reading_trend_loading');

  /// 読書統計グラフ: 空状態
  static const Key readingTrendEmpty = Key('reading_trend_empty');

  /// 読書統計グラフ: サマリーカード
  static const Key readingTrendSummary = Key('reading_trend_summary');

  /// 読書統計グラフ: 月別読了冊数 棒グラフ
  static const Key readingTrendFinishedChart =
      Key('reading_trend_finished_chart');

  /// 読書統計グラフ: 月別読書時間 折れ線グラフ
  static const Key readingTrendMinutesChart =
      Key('reading_trend_minutes_chart');

  /// 読書統計グラフ: ジャンル分布 円グラフ
  static const Key readingTrendGenreChart = Key('reading_trend_genre_chart');

  /// 読書の日次目標画面への導線（本棚 AppBar）
  static const Key dailyGoalEntry = Key('daily_goal_entry');

  /// 読書の日次目標画面（Scaffold）
  static const Key dailyGoalScreen = Key('daily_goal_screen');

  /// 読書の日次目標: 今日のカード
  static const Key dailyGoalTodayCard = Key('daily_goal_today_card');

  /// 読書の日次目標: 進捗バー
  static const Key dailyGoalProgressBar = Key('daily_goal_progress_bar');

  /// 読書の日次目標: 連続達成ラベル
  static const Key dailyGoalStreakLabel = Key('daily_goal_streak_label');

  /// 読書の日次目標: 目標未設定表示
  static const Key dailyGoalEmpty = Key('daily_goal_empty');

  /// 読書の日次目標: 分数入力欄
  static const Key dailyGoalMinutesField = Key('daily_goal_minutes_field');

  /// 読書の日次目標: 保存ボタン
  static const Key dailyGoalSaveButton = Key('daily_goal_save_button');

  /// 読書の日次目標: 目標解除ボタン
  static const Key dailyGoalClearButton = Key('daily_goal_clear_button');

  /// 読書の日次目標: プリセットチップ（分を指定）
  static Key dailyGoalPresetChip(int minutes) =>
      Key('daily_goal_preset_$minutes');

  /// 読書の日次目標: 直近7日の各セル（'YYYY-MM-DD'を指定）
  static Key dailyGoalDayCell(String date) => Key('daily_goal_day_$date');

  /// 読書シェアカード画面（Scaffold）
  static const Key shareCardScreen = Key('screen_share_card');

  /// 読書シェアカード: プレビューカード
  static const Key shareCardPreview = Key('share_card_preview');

  /// 読書シェアカード: テキスト共有ボタン
  static const Key shareCardTextShareButton = Key('share_card_text_share');

  /// 読書シェアカード: 画像共有ボタン
  static const Key shareCardImageShareButton = Key('share_card_image_share');

  /// 読書シェアカード画面への導線（統計 AppBar アクション）
  static const Key statsShareCardEntry = Key('stats_share_card_entry');

  /// 期間レポート画面への導線（統計 AppBar アクション）
  static const Key periodReportEntry = Key('period_report_entry');

  /// 期間レポート画面（Scaffold）
  static const Key periodReportScreen = Key('screen_period_report');

  /// 期間レポート: ローディング状態
  static const Key periodReportLoading = Key('period_report_loading');

  /// 期間レポート: 週次トグル
  static const Key periodReportRangeWeek = Key('period_report_range_week');

  /// 期間レポート: 月次トグル
  static const Key periodReportRangeMonth = Key('period_report_range_month');

  /// 期間レポート: 前の期間ボタン
  static const Key periodReportPrevButton = Key('period_report_prev_button');

  /// 期間レポート: 次の期間ボタン
  static const Key periodReportNextButton = Key('period_report_next_button');

  /// 期間レポート: 期間ラベル
  static const Key periodReportPeriodLabel = Key('period_report_period_label');

  /// 期間レポート: 読了冊数
  static const Key periodReportFinishedCount =
      Key('period_report_finished_count');

  /// 期間レポート: 総読書時間
  static const Key periodReportTotalMinutes =
      Key('period_report_total_minutes');

  /// 期間レポート: 空状態
  static const Key periodReportEmpty = Key('period_report_empty');

  /// 期間レポート: お気に入りレビューの行（index を指定）
  static Key periodReportFavoriteReview(int index) =>
      Key('period_report_favorite_review_$index');

  /// 実績バッジ画面への導線（統計 AppBar アクション）
  static const Key badgeCollectionEntry = Key('badge_collection_entry');

  /// 実績バッジ画面（AppBar）
  static const Key badgeCollectionScreen = Key('badge_collection_screen');

  /// 実績バッジ: 獲得率サマリーラベル
  static const Key badgeSummaryLabel = Key('badge_summary_label');

  /// 実績バッジ: 絞込チップ（すべて）
  static const Key badgeFilterAll = Key('badge_filter_all');

  /// 実績バッジ: 絞込チップ（獲得済み）
  static const Key badgeFilterEarned = Key('badge_filter_earned');

  /// 実績バッジ: 絞込チップ（未獲得）
  static const Key badgeFilterUnearned = Key('badge_filter_unearned');

  /// 実績バッジ: 空状態
  static const Key badgeEmpty = Key('badge_empty');

  /// 実績バッジ: 指定バッジの行（id を指定）
  static Key badgeRow(String id) => Key('badge_row_$id');

  /// 貸出管理画面（Scaffold）
  static const Key loanManagementScreen = Key('loan_management_screen');

  /// 貸出管理: 絞込チップ（すべて）
  static const Key loanFilterAll = Key('loan_filter_all');

  /// 貸出管理: 絞込チップ（貸出中）
  static const Key loanFilterActive = Key('loan_filter_active');

  /// 貸出管理: 絞込チップ（返却予定間近・期限超過を含む）
  static const Key loanFilterDueSoon = Key('loan_filter_due_soon');

  /// 貸出管理: 絞込チップ（履歴＝返却済み）
  static const Key loanFilterReturned = Key('loan_filter_returned');

  /// 貸出管理: 借り手名の検索欄
  static const Key loanSearchField = Key('loan_search_field');

  /// 貸出管理・蔵書詳細: 貸出が無いときの空状態
  static const Key loanEmpty = Key('loan_empty');

  /// 貸出ダイアログ: 借り手名の入力欄
  static const Key loanBorrowerField = Key('loan_borrower_field');

  /// 貸出ダイアログ: 返却予定日の選択ボタン
  static const Key loanDueButton = Key('loan_due_button');

  /// 貸出ダイアログ: 確定ボタン
  static const Key loanSaveButton = Key('loan_save_button');

  /// 蔵書詳細: 貸出中一覧画面への導線
  static const Key loanEntryButton = Key('loan_entry_button');

  /// 蔵書詳細: 貸出セクション
  static const Key loanDetailSection = Key('loan_detail_section');

  /// 蔵書詳細: 現在の貸出状況（借り手 / 期限）
  static const Key loanDetailStatusLabel = Key('loan_detail_status_label');

  /// 蔵書詳細: 貸出を記録ボタン
  static const Key loanLendButton = Key('loan_lend_button');

  /// 貸出: 指定貸出の返却ボタン
  static Key loanReturnButton(String loanId) => Key('loan_return_button_$loanId');

  /// 貸出: 指定貸出の行
  static Key loanRow(String loanId) => Key('loan_row_$loanId');

  /// 蔵書詳細: 所在セクション
  static const Key locationSection = Key('location_section');

  /// 蔵書詳細: 所在編集の導線
  static const Key locationEditButton = Key('location_edit_button');

  /// 蔵書詳細: 所在入力欄（ダイアログ内）
  static const Key locationInput = Key('location_input');

  /// 蔵書詳細: 所在の保存ボタン（ダイアログ内）
  static const Key locationSave = Key('location_save');

  /// 蔵書詳細: 所在を消すボタン（ダイアログ内）
  static const Key locationClear = Key('location_clear');

  /// 蔵書詳細: 所在表示テキスト
  static const Key locationValue = Key('location_value');

  /// 本棚: 指定所在の絞り込みチップ
  static Key locationFilterChip(String location) =>
      Key('library_location_chip_$location');

  /// 貸出管理: 返却期限の通知設定セクション
  static const Key loanDueReminderSection = Key('loan_due_reminder_section');

  /// 貸出管理: 返却期限の通知 ON/OFF
  static const Key loanDueReminderSwitch = Key('loan_due_reminder_switch');

  /// 貸出管理: 返却期限の通知時刻（時）
  static const Key loanDueReminderHour = Key('loan_due_reminder_hour');

  /// 貸出管理: 返却期限の通知設定 保存ボタン
  static const Key loanDueReminderSave = Key('loan_due_reminder_save');

  /// 貸出管理: 返却期限の通知状態文言
  static const Key loanDueReminderStatus = Key('loan_due_reminder_status');

  /// 本棚: 重複蔵書のバナー
  static const Key duplicateBanner = Key('bookshelf_duplicate_banner');

  /// 本棚: 重複整理画面への導線
  static const Key duplicateOpenButton = Key('bookshelf_duplicate_open');

  /// 重複整理: 組カード
  static Key duplicateGroupCard(String isbnKey) => Key('duplicate_group_$isbnKey');

  /// 重複整理: 代表選択ラジオ
  static Key duplicateKeepRadio(String bookId) => Key('duplicate_keep_$bookId');

  /// 重複整理: 統合ボタン
  static Key duplicateMergeButton(String isbnKey) =>
      Key('duplicate_merge_$isbnKey');

  /// 重複整理: 個別削除ボタン
  static Key duplicateDeleteButton(String bookId) =>
      Key('duplicate_delete_$bookId');

  /// 重複整理: 空状態
  static const Key duplicateEmpty = Key('duplicate_empty');
}
