import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:book_review_app/features/auto_backup/data/auto_backup_store.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:book_review_app/features/auto_backup/domain/auto_backup_service.dart';

/// 起動直後の自動バックアップを投げっぱなしで予約する。
///
/// `runApp` を待たせない。失敗しても例外は外へ出さず、
/// デバッグ時のみ [debugPrint] に残す（起動の邪魔をしない）。
void scheduleAutoBackup({
  required Future<String> Function() buildJson,
  AutoBackupStore? store,
  AutoBackupPolicy policy = const AutoBackupPolicy(),
}) {
  final service = AutoBackupService(
    store: store ?? FileAutoBackupStore(),
    policy: policy,
  );
  unawaited(
    service.run(buildJson).then<void>(
      (result) {
        if (result.error != null) {
          debugPrint('自動バックアップ失敗: ${result.error}');
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('自動バックアップ失敗: $error');
      },
    ),
  );
}
