import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/domain/repositories/book_loan_repository.dart';

/// Hive を使用した [BookLoanRepository] の実装。
///
/// 貸出は JSON 文字列として保存する（TypeAdapter 不要）。
/// 破損エントリは読み飛ばし、他のエントリの読み取りを妨げない。
class HiveBookLoanRepository implements BookLoanRepository {
  late Box<String> _box;

  /// Hive のボックス名。
  static const String defaultBoxName = 'book_loans';

  /// 初期化（テスト時は boxName を指定して呼び出す）。
  Future<void> init({String? boxName}) async {
    _box = await Hive.openBox<String>(boxName ?? defaultBoxName);
  }

  /// ボックスをクリアする。
  Future<void> clear() async {
    await _box.clear();
  }

  /// ボックスを閉じる。
  Future<void> close() async {
    await _box.close();
  }

  /// 破損エントリを読み飛ばして全件復元する。
  List<BookLoan> _readAll() {
    final loans = <BookLoan>[];
    for (final raw in _box.values) {
      final loan = _decode(raw);
      if (loan != null) loans.add(loan);
    }
    return loans;
  }

  BookLoan? _decode(String raw) {
    try {
      final map = json.decode(raw);
      if (map is! Map<String, dynamic>) return null;
      return BookLoan.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<BookLoan>> loadLoans() async => _readAll();

  @override
  Future<void> saveLoans(List<BookLoan> loans) async {
    await _box.clear();
    for (final loan in loans) {
      await _box.put(loan.id, json.encode(loan.toJson()));
    }
  }
}

/// テスト・プレビュー用のインメモリ実装。
class InMemoryBookLoanRepository implements BookLoanRepository {
  final Map<String, BookLoan> _store = {};

  /// 現在保持している件数。
  int get length => _store.length;

  @override
  Future<List<BookLoan>> loadLoans() async => _store.values.toList();

  @override
  Future<void> saveLoans(List<BookLoan> loans) async {
    _store
      ..clear()
      ..addEntries([for (final l in loans) MapEntry(l.id, l)]);
  }
}

/// 何もしない実装（プレビュー・フォールバック用）。
class NoopBookLoanRepository implements BookLoanRepository {
  @override
  Future<List<BookLoan>> loadLoans() async => const [];

  @override
  Future<void> saveLoans(List<BookLoan> loans) async {}
}
