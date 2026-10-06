import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/stats/domain/reading_pace.dart';

void main() {
  group('ReadingPaceStatus.label', () {
    test('各ステータスの日本語ラベルを返す', () {
      expect(ReadingPaceStatus.ok.label, '読了予測あり');
      expect(ReadingPaceStatus.finished.label, '読了済み');
      expect(ReadingPaceStatus.noPageCount.label, 'ページ数未登録');
      expect(ReadingPaceStatus.noPace.label, 'ペース推定不能');
    });
  });

  group('FinishForecast', () {
    FinishForecast build({
      ReadingPaceStatus status = ReadingPaceStatus.ok,
      double? pagesPerDay = 20.0,
      int? daysRemaining = 5,
      DateTime? finishDate,
    }) {
      return FinishForecast(
        bookId: 'b1',
        title: '本',
        currentPage: 100,
        pageCount: 200,
        remainingPages: 100,
        pagesPerDay: pagesPerDay,
        daysRemaining: daysRemaining,
        finishDate: finishDate ?? DateTime(2026, 10, 11),
        status: status,
      );
    }

    test('同値の2インスタンスは等価', () {
      expect(build(), build());
    });

    test('値が異なれば非等価', () {
      expect(build(), isNot(build(daysRemaining: 6)));
    });

    test('hashCode は同値なら一致', () {
      expect(build().hashCode, build().hashCode);
    });

    test('status=ok の summaryLabel は残り日数と読了予定日を含む', () {
      final f = build(
        daysRemaining: 12,
        finishDate: DateTime(2026, 10, 18),
      );
      expect(f.summaryLabel, 'あと12日（2026/10/18）に読了見込み');
    });

    test('status=finished の summaryLabel', () {
      expect(
        build(status: ReadingPaceStatus.finished).summaryLabel,
        '読了済み',
      );
    });

    test('status=noPageCount の summaryLabel', () {
      expect(
        build(status: ReadingPaceStatus.noPageCount).summaryLabel,
        'ページ数が未登録です',
      );
    });

    test('status=noPace の summaryLabel', () {
      expect(
        build(
          status: ReadingPaceStatus.noPace,
          pagesPerDay: null,
          daysRemaining: null,
          finishDate: null,
        ).summaryLabel,
        '読書セッションが無く推定できません',
      );
    });

    test('remainingPages が不正（負）なら ArgumentError', () {
      expect(
        () => FinishForecast(
          bookId: 'b1',
          title: '本',
          currentPage: 100,
          pageCount: 200,
          remainingPages: -1,
          pagesPerDay: null,
          daysRemaining: null,
          finishDate: null,
          status: ReadingPaceStatus.noPageCount,
        ),
        throwsArgumentError,
      );
    });
  });
}
