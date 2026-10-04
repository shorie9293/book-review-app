/// 読書セッションの純粋なドメインサービス（I/O なし・時刻は注入）。
library;

import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/reading/domain/reading_stats.dart';

/// 日別の読書合計。
class DailyReadingTotal {
  final DateTime day;
  final int minutes;

  const DailyReadingTotal({required this.day, required this.minutes});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyReadingTotal &&
          other.day == day &&
          other.minutes == minutes;

  @override
  int get hashCode => Object.hash(day, minutes);

  @override
  String toString() => 'DailyReadingTotal(day: $day, minutes: $minutes)';
}

class ReadingSessionService {
  const ReadingSessionService();

  /// セッション開始時刻と終了時刻からセッションを作る。
  /// 終了 <= 開始 は ArgumentError。id は呼出側が渡す。
  ReadingSession fromInterval({
    required String id,
    String? bookId,
    String? bookTitle,
    required DateTime startedAt,
    required DateTime endedAt,
  }) {
    if (!endedAt.isAfter(startedAt)) {
      throw ArgumentError.value(
        endedAt,
        'endedAt',
        'endedAt は startedAt より後でなければならない',
      );
    }
    final minutes = endedAt.difference(startedAt).inMinutes;
    return ReadingSession(
      id: id,
      bookId: bookId,
      bookTitle: bookTitle,
      startedAt: startedAt,
      durationMinutes: minutes <= 0 ? 1 : minutes,
    );
  }

  /// 現在進行中の経過を分に丸めて返す（経過0分未満は0）。
  int elapsedMinutes(DateTime startedAt, DateTime now) {
    final minutes = now.difference(startedAt).inMinutes;
    return minutes <= 0 ? 0 : minutes;
  }

  /// 日付（時刻を落としたもの）ごとの合計分。
  Map<DateTime, int> minutesByDay(List<ReadingSession> sessions) {
    final totals = <DateTime, int>{};
    for (final session in sessions) {
      final key = _dateOf(session.startedAt);
      totals[key] = (totals[key] ?? 0) + session.durationMinutes;
    }
    return totals;
  }

  /// 直近 limit 日（now の日を含む）の日別合計分。
  /// 日付昇順・セッションの無い日は 0。
  List<DailyReadingTotal> recentDailyTotals(
    List<ReadingSession> sessions,
    DateTime now, {
    int days = 7,
  }) {
    if (days <= 0) return const [];
    final byDay = minutesByDay(sessions);
    final today = _dateOf(now);
    final result = <DailyReadingTotal>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      result.add(DailyReadingTotal(day: day, minutes: byDay[day] ?? 0));
    }
    return result;
  }

  /// 合計統計。空リストでも落ちない。
  ReadingStats summarize(List<ReadingSession> sessions) {
    if (sessions.isEmpty) return const ReadingStats.empty();
    var totalMinutes = 0;
    final bookIds = <String>{};
    final days = <DateTime>{};
    for (final session in sessions) {
      totalMinutes += session.durationMinutes;
      final bookId = session.bookId;
      if (bookId != null) bookIds.add(bookId);
      days.add(_dateOf(session.startedAt));
    }
    return ReadingStats(
      totalMinutes: totalMinutes,
      sessionCount: sessions.length,
      bookCount: bookIds.length,
      activeDays: days.length,
    );
  }

  /// startedAt 降順（同時刻は id 昇順）の安定ソート。入力非破壊。
  List<ReadingSession> sortByRecent(List<ReadingSession> sessions) {
    final sorted = [...sessions];
    sorted.sort((a, b) {
      final byTime = b.startedAt.compareTo(a.startedAt);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  /// bookId で絞り込み（null 指定は「紐づきなし」を意味する）。
  List<ReadingSession> filterByBook(
    List<ReadingSession> sessions,
    String? bookId,
  ) {
    return [
      for (final session in sessions)
        if (session.bookId == bookId) session,
    ];
  }

  DateTime _dateOf(DateTime at) => DateTime(at.year, at.month, at.day);
}
