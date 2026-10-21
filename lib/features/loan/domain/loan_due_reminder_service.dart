import 'package:book_review_app/domain/models/book_loan.dart';

/// 返却期限アラートの種別。
enum LoanDueAlertKind { overdue, today, tomorrow }

/// [LoanDueAlertKind] の日本語ラベル。
extension LoanDueAlertKindLabel on LoanDueAlertKind {
  String get label {
    switch (this) {
      case LoanDueAlertKind.overdue:
        return '期限超過';
      case LoanDueAlertKind.today:
        return '本日返却';
      case LoanDueAlertKind.tomorrow:
        return '明日返却';
    }
  }
}

/// 1件の返却期限アラート。
class LoanDueAlert {
  const LoanDueAlert({
    required this.loanId,
    required this.bookId,
    required this.bookTitle,
    required this.kind,
    this.daysOverdue = 0,
  })  : assert(daysOverdue >= 0, 'daysOverdue must not be negative');

  final String loanId;
  final String bookId;
  final String bookTitle;
  final LoanDueAlertKind kind;

  /// 期限超過日数。[LoanDueAlertKind.overdue] 以外は 0。
  final int daysOverdue;

  /// 表示用ラベル。例: `期限超過（3日）` / `本日返却` / `明日返却`。
  String get label {
    switch (kind) {
      case LoanDueAlertKind.overdue:
        return '${kind.label}（$daysOverdue日）';
      case LoanDueAlertKind.today:
        return kind.label;
      case LoanDueAlertKind.tomorrow:
        return kind.label;
    }
  }

  /// 本文の1行。例: `・ガリア戦記 — 期限超過（3日）`。
  /// 書名が空の場合は [bookId] を表示する。
  String get line {
    final title = bookTitle.isEmpty ? bookId : bookTitle;
    return '・$title — $label';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanDueAlert &&
          other.loanId == loanId &&
          other.bookId == bookId &&
          other.bookTitle == bookTitle &&
          other.kind == kind &&
          other.daysOverdue == daysOverdue;

  @override
  int get hashCode =>
      Object.hash(loanId, bookId, bookTitle, kind, daysOverdue);

  @override
  String toString() => 'LoanDueAlert($line)';
}

/// 通知1回分のアラート集合。
class LoanDueReminderPlan {
  LoanDueReminderPlan(List<LoanDueAlert> alerts)
      : alerts = List<LoanDueAlert>.unmodifiable(alerts);

  /// アラート0件のプラン。
  const LoanDueReminderPlan.empty() : alerts = const <LoanDueAlert>[];

  /// 不変リスト。overdue（日数降順）→ today → tomorrow。
  final List<LoanDueAlert> alerts;

  bool get isEmpty => alerts.isEmpty;

  int get count => alerts.length;

  /// 通知本文。[isEmpty] の場合は空文字。末尾改行なし。
  String get body {
    if (isEmpty) return '';
    final buffer = StringBuffer('📚 返却期限のお知らせ');
    for (final alert in alerts) {
      buffer
        ..write('\n')
        ..write(alert.line);
    }
    buffer
      ..write('\n')
      ..write('合計 $count件');
    return buffer.toString();
  }

  @override
  String toString() => 'LoanDueReminderPlan(count: $count)';
}

/// 返却期限リマインダーの純粋ロジック。
///
/// I/O や `DateTime.now()` の直読みは行わない。現在日時は必ず
/// 名前付き必須引数 `now` として注入する。
class LoanDueReminderService {
  LoanDueReminderService._();

  /// 未返却かつ期限が「期限超過 / 本日 / 明日」の貸出から通知計画を組む。
  ///
  /// 日付差はローカル日付の0時同士を `DateTime(y, m, d)` で比較して
  /// 日数化する（DST の影響を避けるため）。
  static LoanDueReminderPlan build({
    required List<BookLoan> loans,
    required DateTime now,
    Map<String, String> bookTitles = const {},
  }) {
    final today = _startOfDay(now);
    final alerts = <LoanDueAlert>[];

    for (final loan in loans) {
      if (loan.isReturned) continue;
      final due = loan.dueAt;
      if (due == null) continue;
      final diff = _daysBetween(today, _startOfDay(due));
      final LoanDueAlertKind kind;
      final int daysOverdue;
      if (diff < 0) {
        kind = LoanDueAlertKind.overdue;
        daysOverdue = -diff;
      } else if (diff == 0) {
        kind = LoanDueAlertKind.today;
        daysOverdue = 0;
      } else if (diff == 1) {
        kind = LoanDueAlertKind.tomorrow;
        daysOverdue = 0;
      } else {
        continue;
      }
      alerts.add(LoanDueAlert(
        loanId: loan.id,
        bookId: loan.bookId,
        bookTitle: bookTitles[loan.bookId] ?? loan.bookId,
        kind: kind,
        daysOverdue: daysOverdue,
      ));
    }

    alerts.sort(_compareAlerts);
    return LoanDueReminderPlan(alerts);
  }

  /// overdue（daysOverdue 降順）→ today → tomorrow、同順位は loanId 昇順。
  static int _compareAlerts(LoanDueAlert a, LoanDueAlert b) {
    final byKind = _kindRank(a.kind) - _kindRank(b.kind);
    if (byKind != 0) return byKind;
    final byDays = b.daysOverdue - a.daysOverdue;
    if (byDays != 0) return byDays;
    return a.loanId.compareTo(b.loanId);
  }

  static int _kindRank(LoanDueAlertKind kind) {
    switch (kind) {
      case LoanDueAlertKind.overdue:
        return 0;
      case LoanDueAlertKind.today:
        return 1;
      case LoanDueAlertKind.tomorrow:
        return 2;
    }
  }

  static DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  /// 暦日単位の差（DST の影響を受けないよう UTC の日付で計算）。
  static int _daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }
}
