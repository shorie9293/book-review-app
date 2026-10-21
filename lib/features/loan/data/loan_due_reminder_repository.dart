import 'dart:convert';

import 'package:book_review_app/features/loan/domain/loan_due_reminder_settings.dart';
import 'package:hive/hive.dart';

/// 返却期限リマインダー設定の永続化インターフェース。
abstract class LoanDueReminderRepository {
  Future<LoanDueReminderSettings> load();
  Future<void> save(LoanDueReminderSettings s);
}

/// Hive 実装。box `loan_reminder_box` / key `loanDueReminder` に
/// JSON 文字列で保存。破損・型不一致レコードは
/// [LoanDueReminderSettings.defaults] へフォールバックする。
class HiveLoanDueReminderRepository implements LoanDueReminderRepository {
  static const String boxName = 'loan_reminder_box';
  static const String keyName = 'loanDueReminder';

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<String>(boxName);
    return _box!;
  }

  @override
  Future<LoanDueReminderSettings> load() async {
    final box = await _getBox();
    final raw = box.get(keyName);
    if (raw is! String) return LoanDueReminderSettings.defaults();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return LoanDueReminderSettings.defaults();
      }
      return LoanDueReminderSettings.fromJson(decoded);
    } catch (_) {
      return LoanDueReminderSettings.defaults();
    }
  }

  @override
  Future<void> save(LoanDueReminderSettings s) async {
    final box = await _getBox();
    await box.put(keyName, jsonEncode(s.toJson()));
  }
}

/// 試練用のメモリ内リポジトリ。初期値を注入できる。
class InMemoryLoanDueReminderRepository implements LoanDueReminderRepository {
  InMemoryLoanDueReminderRepository([LoanDueReminderSettings? initial])
      : _settings = initial ?? LoanDueReminderSettings.defaults();

  LoanDueReminderSettings _settings;

  @override
  Future<LoanDueReminderSettings> load() async => _settings;

  @override
  Future<void> save(LoanDueReminderSettings s) async => _settings = s;
}
