import 'package:flutter/material.dart';

import 'package:book_review_app/features/auto_backup/data/auto_backup_restorer_impl.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_sharer_impl.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:book_review_app/features/auto_backup/presentation/auto_backup_screen.dart';
import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/domain/backup_models.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/loan/data/hive_book_loan_repository.dart';
import 'package:book_review_app/features/loan/infrastructure/loan_due_reminder_resync_factory.dart';
import 'package:book_review_app/features/notes/data/hive_book_note_repository.dart';
import 'package:book_review_app/features/review/data/hive_review_repository.dart';

/// 起動時自動バックアップと同じ経路で現状 JSON を組み立てる。
Future<String> _buildCurrentJson() async {
  final repository = await _openBackupRepository();
  final bundle = await repository.collect();
  return const BackupService().exportJson(bundle);
}

/// 自動バックアップ復元の内訳表示用: 現状のバンドルを採取する。
Future<BackupBundle> _collectCurrentBundle() async {
  final repository = await _openBackupRepository();
  return repository.collect();
}

/// 回復導線用: 現状をバックアップファイルとして1回書き出す。
///
/// 起動時自動バックアップと同じ「収集 → JSON化 → 保存先書込み」を再利用する。
Future<void> exportBackupSnapshot() async {
  final json = await _buildCurrentJson();
  await FileAutoBackupStore().write(
    AutoBackupPolicy.fileNameFor(DateTime.now()),
    json,
  );
}

/// 既存の手動バックアップ復元経路で JSON を適用する。
///
/// [includeSettings] が false なら控えの設定（テーマ・文字サイズ等）は
/// 適用せず記録だけを戻す。
Future<void> _applyJson(String json, {bool includeSettings = true}) async {
  final bundle = const BackupService().parse(json);
  final repository = await _openBackupRepository();
  await repository.restore(bundle, includeSettings: includeSettings);
}

/// 設定を戻した後の通知の再予約（返却期限リマインダーの組み直し）。
///
/// 設定の適用で端末の見え方・通知条件が変わり得るため、既存の
/// 「返却期限リマインダー再同期」をそのまま1回走らせる。
/// 失敗しても復元結果は落とさない（呼び出し側が投げっぱなしで握る）。
Future<void> _resyncNotificationsAfterSettings() async {
  final loanRepository = HiveBookLoanRepository();
  await loanRepository.init();
  await createHiveLoanDueReminderResync(
    loanRepository: loanRepository,
  ).trigger();
}

Future<HiveBackupRepository> _openBackupRepository() async {
  final bookRepository = HiveBookRepository();
  final reviewRepository = HiveReviewRepository();
  final noteRepository = HiveBookNoteRepository();
  await bookRepository.init();
  await reviewRepository.init();
  await noteRepository.init();
  return HiveBackupRepository(
    bookRepository: bookRepository,
    reviewRepository: reviewRepository,
    noteRepository: noteRepository,
  );
}

/// 実端末向けの自動バックアップ画面を組み立てる（設定ハブの既定導線）。
Widget buildAutoBackupScreen() {
  final store = FileAutoBackupStore();
  return AutoBackupScreen(
    store: store,
    restorer: AutoBackupRestorerImpl(
      store: store,
      buildCurrentJson: _buildCurrentJson,
      applyBackup: _applyJson,
      applyBackupWithOptions: _applyJson,
      onSettingsRestored: _resyncNotificationsAfterSettings,
    ),
    sharer: SharePlusAutoBackupSharer(),
    statusStore: FileAutoBackupStatusStore(),
    existingBundleLoader: _collectCurrentBundle,
    onBackupNow: () async {
      final json = await _buildCurrentJson();
      await store.write(AutoBackupPolicy.fileNameFor(DateTime.now()), json);
    },
  );
}
