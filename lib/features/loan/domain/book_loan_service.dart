import 'package:book_review_app/domain/models/book_loan.dart';

/// 期限バケット。
enum LoanBucket { none, overdue, today, soon, later }

/// [LoanBucket] の日本語ラベル。
extension LoanBucketLabel on LoanBucket {
  String get label {
    switch (this) {
      case LoanBucket.none:
        return '対象外';
      case LoanBucket.overdue:
        return '期限超過';
      case LoanBucket.today:
        return '本日返却';
      case LoanBucket.soon:
        return 'まもなく';
      case LoanBucket.later:
        return '余裕あり';
    }
  }
}

/// 貸出に関する純粋ロジック。
///
/// I/O や `DateTime.now()` の直読みは行わない。現在日時は必ず
/// 名前付き必須引数 `now` として注入する。
class BookLoanService {
  BookLoanService._();

  /// 既定の「まもなく」判定日数。
  static const int defaultWithinDays = 7;

  /// 未返却の貸出。dueAt 昇順（null 末尾）→ lentAt 昇順 → id 昇順。
  static List<BookLoan> activeLoans(List<BookLoan> loans) {
    final result = loans.where((l) => !l.isReturned).toList()
      ..sort((a, b) {
        final byDue = _compareDateAsc(a.dueAt, b.dueAt);
        if (byDue != 0) return byDue;
        final byLent = a.lentAt.compareTo(b.lentAt);
        if (byLent != 0) return byLent;
        return a.id.compareTo(b.id);
      });
    return result;
  }

  /// 返却済の貸出。returnedAt 降順（null 末尾）→ id 昇順。
  static List<BookLoan> returnedLoans(List<BookLoan> loans) {
    final result = loans.where((l) => l.isReturned).toList()
      ..sort((a, b) {
        final byReturned = _compareDateDesc(a.returnedAt, b.returnedAt);
        if (byReturned != 0) return byReturned;
        return a.id.compareTo(b.id);
      });
    return result;
  }

  /// 未返却かつ dueAt が [now] の当日0時より前の貸出。
  static List<BookLoan> overdueLoans(
    List<BookLoan> loans, {
    required DateTime now,
  }) {
    final today = _startOfDay(now);
    return loans
        .where((l) =>
            !l.isReturned && l.dueAt != null && l.dueAt!.isBefore(today))
        .toList();
  }

  /// 未返却かつ dueAt が当日0時以上〜[withinDays] 日後0時未満の貸出。
  static List<BookLoan> dueSoonLoans(
    List<BookLoan> loans, {
    required DateTime now,
    int withinDays = defaultWithinDays,
  }) {
    final today = _startOfDay(now);
    final limit = _addDays(today, withinDays);
    return loans.where((l) {
      if (l.isReturned || l.dueAt == null) return false;
      final due = l.dueAt!;
      return !due.isBefore(today) && due.isBefore(limit);
    }).toList();
  }

  /// 貸出を期限バケットに分類する。
  static LoanBucket bucketOf(
    BookLoan loan, {
    required DateTime now,
    int withinDays = defaultWithinDays,
  }) {
    if (loan.isReturned) return LoanBucket.none;
    final due = loan.dueAt;
    if (due == null) return LoanBucket.later;
    final today = _startOfDay(now);
    if (due.isBefore(today)) return LoanBucket.overdue;
    if (due.isBefore(_addDays(today, 1))) return LoanBucket.today;
    if (due.isBefore(_addDays(today, withinDays))) return LoanBucket.soon;
    return LoanBucket.later;
  }

  /// [bookId] の未返却貸出のうち lentAt 最新のもの。
  ///
  /// 同時刻の場合は id 昇順で最後のものを返す。無ければ null。
  static BookLoan? activeLoanFor(List<BookLoan> loans, String bookId) {
    BookLoan? latest;
    for (final l in loans) {
      if (l.isReturned || l.bookId != bookId) continue;
      if (latest == null) {
        latest = l;
        continue;
      }
      final cmp = l.lentAt.compareTo(latest.lentAt);
      if (cmp > 0 || (cmp == 0 && l.id.compareTo(latest.id) > 0)) {
        latest = l;
      }
    }
    return latest;
  }

  /// [loan] を非破壊で追加する。
  ///
  /// 同一 [BookLoan.bookId] に未返却の貸出が既にあれば [ArgumentError]。
  static List<BookLoan> addLoan(List<BookLoan> loans, BookLoan loan) {
    final duplicate = loans.any(
        (l) => !l.isReturned && l.bookId == loan.bookId);
    if (duplicate) {
      throw ArgumentError.value(
          loan.bookId, 'bookId', 'active loan already exists for this book');
    }
    return [...loans, loan];
  }

  /// [loanId] の貸出を返却済みにする（非破壊）。
  ///
  /// 未知の id の場合は同内容の新しいリストを返す（例外なし）。
  static List<BookLoan> markReturned(
    List<BookLoan> loans,
    String loanId,
    DateTime returnedAt,
  ) {
    return [
      for (final l in loans)
        if (l.id == loanId) l.copyWith(returnedAt: returnedAt) else l,
    ];
  }

  /// 借り手名の部分一致検索。
  ///
  /// 正規化: 全角英数・全角スペース→半角、trim、小文字化。
  /// 空クエリ（正規化後）は全件を返す。
  static List<BookLoan> search(List<BookLoan> loans, String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return [...loans];
    return loans
        .where((l) => _normalize(l.borrower).contains(normalized))
        .toList();
  }

  /// 期限の表示ラベル。
  static String dueLabel(BookLoan loan, {required DateTime now}) {
    if (loan.isReturned) return '返却済';
    final due = loan.dueAt;
    if (due == null) return '期限なし';
    final today = _startOfDay(now);
    if (due.isBefore(today)) {
      return '期限超過 ${_daysBetween(due, today)}日';
    }
    if (due.isBefore(_addDays(today, 1))) return '本日返却';
    return 'あと${_daysBetween(today, due)}日';
  }

  /// 一覧サマリの表示ラベル。
  static String summaryLabel(List<BookLoan> loans, {required DateTime now}) {
    final active = activeLoans(loans).length;
    if (active == 0) return '貸出中 0冊';
    final overdue = overdueLoans(loans, now: now).length;
    if (overdue == 0) return '貸出中 $active冊';
    return '貸出中 $active冊（期限超過 $overdue）';
  }

  static DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  /// 暦日単位の差（DST の影響を受けないよう UTC の日付で計算）。
  static int _daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static int _compareDateAsc(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  static int _compareDateDesc(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  static String _normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune == 0x3000) {
        buffer.writeCharCode(0x20);
      } else if (rune >= 0xFF01 && rune <= 0xFF5E) {
        buffer.writeCharCode(rune - 0xFEE0);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().trim().toLowerCase();
  }
}
