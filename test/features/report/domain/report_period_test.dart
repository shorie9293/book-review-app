// 期間レポート機能の試練（ReportPeriod）。
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/report/domain/report_period.dart';

void main() {
  group('ReportPeriod.weekOf', () {
    test('月曜日付から作るとそのまま週を切る', () {
      final p = ReportPeriod.weekOf(DateTime(2026, 10, 12));
      expect(p.start, DateTime(2026, 10, 12));
      expect(p.endExclusive, DateTime(2026, 10, 19));
      expect(p.range, ReportRange.week);
    });
    test('日曜日付から作ると同じ週の月曜に戻る', () {
      final p = ReportPeriod.weekOf(DateTime(2026, 10, 18));
      expect(p.start, DateTime(2026, 10, 12));
      expect(p.endExclusive, DateTime(2026, 10, 19));
    });
    test('時刻付き日付でも0時に正規化される', () {
      final p = ReportPeriod.weekOf(DateTime(2026, 10, 13, 9, 30));
      expect(p.start, DateTime(2026, 10, 12));
    });
    test('月初に跨ぐ週（9/30は水曜）', () {
      final p = ReportPeriod.weekOf(DateTime(2026, 9, 30));
      expect(p.start, DateTime(2026, 9, 28));
      expect(p.endExclusive, DateTime(2026, 10, 5));
    });
    test('年始に跨ぐ週（2026/1/1は木曜）', () {
      final p = ReportPeriod.weekOf(DateTime(2026, 1, 1));
      expect(p.start, DateTime(2025, 12, 29));
      expect(p.endExclusive, DateTime(2026, 1, 5));
    });
    test('days は常に7', () {
      expect(ReportPeriod.weekOf(DateTime(2026, 10, 13)).days, 7);
    });
  });

  group('ReportPeriod.monthOf', () {
    test('月末で切れる', () {
      final p = ReportPeriod.monthOf(DateTime(2026, 10, 13));
      expect(p.start, DateTime(2026, 10, 1));
      expect(p.endExclusive, DateTime(2026, 11, 1));
      expect(p.days, 31);
    });
    test('2月の小月', () {
      final p = ReportPeriod.monthOf(DateTime(2026, 2, 10));
      expect(p.days, 28);
      expect(p.endExclusive, DateTime(2026, 3, 1));
    });
    test('うるう年2024の2月', () {
      final p = ReportPeriod.monthOf(DateTime(2024, 2, 10));
      expect(p.days, 29);
    });
    test('12月は翌年1月1日で切れる', () {
      final p = ReportPeriod.monthOf(DateTime(2026, 12, 31));
      expect(p.endExclusive, DateTime(2027, 1, 1));
    });
  });

  group('previous / next', () {
    test('week: 7日ずつ移動', () {
      final p = ReportPeriod.weekOf(DateTime(2026, 10, 13));
      expect(p.previous().start, DateTime(2026, 10, 5));
      expect(p.next().start, DateTime(2026, 10, 19));
    });
    test('month: 前月・翌月', () {
      final p = ReportPeriod.monthOf(DateTime(2026, 10, 13));
      expect(p.previous().start, DateTime(2026, 9, 1));
      expect(p.previous().endExclusive, DateTime(2026, 10, 1));
      expect(p.next().start, DateTime(2026, 11, 1));
      expect(p.next().endExclusive, DateTime(2026, 12, 1));
    });
    test('month: 1月のpreviousは前年12月', () {
      final prev = ReportPeriod.monthOf(DateTime(2026, 1, 15)).previous();
      expect(prev.start, DateTime(2025, 12, 1));
      expect(prev.endExclusive, DateTime(2026, 1, 1));
    });
    test('month: 12月のnextは翌年1月', () {
      final nxt = ReportPeriod.monthOf(DateTime(2026, 12, 15)).next();
      expect(nxt.start, DateTime(2027, 1, 1));
    });
    test('previous/next の往復で元に戻る', () {
      final p = ReportPeriod.monthOf(DateTime(2026, 10, 13));
      expect(p.previous().next(), p);
      expect(p.next().previous(), p);
    });
  });

  group('contains', () {
    final week = ReportPeriod.weekOf(DateTime(2026, 10, 13)); // 10/12〜10/18
    test('start は含む', () {
      expect(week.contains(DateTime(2026, 10, 12)), isTrue);
    });
    test('endExclusive は含まない', () {
      expect(week.contains(DateTime(2026, 10, 19)), isFalse);
    });
    test('終日前日の終端は含む', () {
      expect(week.contains(DateTime(2026, 10, 18, 23, 59, 59)), isTrue);
    });
    test('期間前・期間後は含まない', () {
      expect(week.contains(DateTime(2026, 10, 11)), isFalse);
      expect(week.contains(DateTime(2026, 10, 20)), isFalse);
    });
  });

  group('label', () {
    test('week: 同月', () {
      expect(
        ReportPeriod.weekOf(DateTime(2026, 10, 13)).label,
        '2026年10月12日〜10月18日',
      );
    });
    test('week: 月跨ぎ', () {
      final p = ReportPeriod.weekOf(DateTime(2026, 9, 30)); // 9/28〜10/4
      expect(p.label, '2026年9月28日〜10月4日');
    });
    test('week: 年跨ぎ', () {
      final p = ReportPeriod.weekOf(DateTime(2026, 1, 1)); // 2025/12/29〜1/4
      expect(p.label, '2025年12月29日〜2026年1月4日');
    });
    test('month', () {
      expect(ReportPeriod.monthOf(DateTime(2026, 10, 13)).label, '2026年10月');
      expect(ReportPeriod.monthOf(DateTime(2026, 1, 13)).label, '2026年1月');
    });
  });

  group('検証', () {
    test('start >= endExclusive は ArgumentError', () {
      expect(
        () => ReportPeriod(
          range: ReportRange.week,
          start: DateTime(2026, 10, 12),
          endExclusive: DateTime(2026, 10, 12),
        ),
        throwsArgumentError,
      );
    });
    test('逆順も ArgumentError', () {
      expect(
        () => ReportPeriod(
          range: ReportRange.month,
          start: DateTime(2026, 11, 1),
          endExclusive: DateTime(2026, 10, 1),
        ),
        throwsArgumentError,
      );
    });
    test('非0時の start は ArgumentError', () {
      expect(
        () => ReportPeriod(
          range: ReportRange.week,
          start: DateTime(2026, 10, 12, 9, 0),
          endExclusive: DateTime(2026, 10, 19),
        ),
        throwsArgumentError,
      );
    });
    test('非0時の endExclusive は ArgumentError', () {
      expect(
        () => ReportPeriod(
          range: ReportRange.week,
          start: DateTime(2026, 10, 12),
          endExclusive: DateTime(2026, 10, 19, 0, 0, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('== / hashCode', () {
    test('同内容は等しい', () {
      final a = ReportPeriod.weekOf(DateTime(2026, 10, 13));
      final b = ReportPeriod.weekOf(DateTime(2026, 10, 14));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
    test('range違いは等しくない', () {
      final w = ReportPeriod.weekOf(DateTime(2026, 10, 13));
      final m = ReportPeriod.monthOf(DateTime(2026, 10, 13));
      expect(w, isNot(m));
    });
    test('自分自身・異型は等しい/等しくない', () {
      final p = ReportPeriod.monthOf(DateTime(2026, 10, 13));
      expect(p, p);
      expect(p, isNot('other'));
    });
  });

  group('endInclusive', () {
    test('endExclusive の1日前', () {
      expect(
        ReportPeriod.monthOf(DateTime(2026, 10, 13)).endInclusive,
        DateTime(2026, 10, 31),
      );
      expect(
        ReportPeriod.weekOf(DateTime(2026, 10, 13)).endInclusive,
        DateTime(2026, 10, 18),
      );
    });
  });
}