import 'package:flutter/material.dart';

import 'package:book_review_app/features/auto_backup/data/auto_backup_restorer_impl.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_sharer_impl.dart';
import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:book_review_app/features/auto_backup/presentation/auto_backup_screen.dart';
import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/notes/data/hive_book_note_repository.dart';
import 'package:book_review_app/features/review/data/hive_review_repository.dart';

/// 起動時自動バックアップと同じ経路で現状 JSON を組み立てる。
Future<String> _buildCurrentJson() async {
  final repository = await _openBackupRepository();
  final bundle = await repository.collect();
  return const BackupService().exportJson(bundle);
}

/// 既存の手動バックアップ復元経路で JSON を適用する。
Future<void> _applyJson(String json) async {
  final bundle = const BackupService().parse(json);
  final repository = await _openBackupRepository();
  await repository.restore(bundle);
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
    ),
    sharer: SharePlusAutoBackupSharer(),
    onBackupNow: () async {
      final json = await _buildCurrentJson();
      await store.write(AutoBackupPolicy.fileNameFor(DateTime.now()), json);
    },
  );
}
