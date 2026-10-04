import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/tutorial/domain/tutorial_progress.dart';

void main() {
  group('初期化', () {
    test('initial ファクトリは currentPage=0 を返すこと', () {
      final p = TutorialProgress.initial(5);
      expect(p.currentPage, 0);
      expect(p.totalPages, 5);
      expect(p.isFirst, isTrue);
    });
  });

  group('isFirst / isLast', () {
    test('currentPage==0 で isFirst', () {
      expect(TutorialProgress.initial(3).isFirst, isTrue);
      expect(const TutorialProgress(currentPage: 1, totalPages: 3).isFirst, isFalse);
    });

    test('末尾で isLast', () {
      expect(const TutorialProgress(currentPage: 2, totalPages: 3).isLast, isTrue);
      expect(const TutorialProgress(currentPage: 1, totalPages: 3).isLast, isFalse);
    });

    test('totalPages<=0 なら常に isLast', () {
      expect(const TutorialProgress(currentPage: 0, totalPages: 0).isLast, isTrue);
    });
  });

  group('pageNumber / label', () {
    test('pageNumber は currentPage+1', () {
      expect(const TutorialProgress(currentPage: 2, totalPages: 5).pageNumber, 3);
    });

    test('totalPages<=0 なら pageNumber は 0', () {
      expect(const TutorialProgress(currentPage: 0, totalPages: 0).pageNumber, 0);
    });

    test('label は "n / total" 形式', () {
      expect(TutorialProgress.initial(5).label, '1 / 5');
      expect(const TutorialProgress(currentPage: 4, totalPages: 5).label, '5 / 5');
    });
  });

  group('fraction', () {
    test('0..1 にクランプされること', () {
      expect(const TutorialProgress(currentPage: 0, totalPages: 4).fraction, 0.25);
      expect(const TutorialProgress(currentPage: 9, totalPages: 4).fraction, 1.0);
    });

    test('totalPages<=0 は 0.0', () {
      expect(const TutorialProgress(currentPage: 0, totalPages: 0).fraction, 0.0);
    });
  });

  group('next / previous / goTo', () {
    test('next は 1 ページ進む', () {
      final p = TutorialProgress.initial(3).next();
      expect(p.currentPage, 1);
    });

    test('末尾で next しても変わらない', () {
      final last = const TutorialProgress(currentPage: 2, totalPages: 3);
      expect(last.next(), last);
    });

    test('previous は 1 ページ戻る', () {
      final p = const TutorialProgress(currentPage: 1, totalPages: 3).previous();
      expect(p.currentPage, 0);
    });

    test('先頭で previous しても変わらない', () {
      final first = TutorialProgress.initial(3);
      expect(first.previous(), first);
    });

    test('goTo は 0..totalPages-1 にクランプ', () {
      final p = TutorialProgress.initial(3);
      expect(p.goTo(-5).currentPage, 0);
      expect(p.goTo(2).currentPage, 2);
      expect(p.goTo(99).currentPage, 2);
    });

    test('totalPages<=0 の goTo は currentPage=0', () {
      expect(const TutorialProgress(currentPage: 0, totalPages: 0).goTo(3).currentPage, 0);
    });
  });

  group('等価性', () {
    test('同値なら == が true / hashCode が一致', () {
      final a = const TutorialProgress(currentPage: 1, totalPages: 5);
      final b = const TutorialProgress(currentPage: 1, totalPages: 5);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('異なる値なら == が false', () {
      final a = const TutorialProgress(currentPage: 1, totalPages: 5);
      expect(a == const TutorialProgress(currentPage: 2, totalPages: 5), isFalse);
      expect(a == const TutorialProgress(currentPage: 1, totalPages: 4), isFalse);
      const dynamic notAProgress = 'not a progress';
      expect(a == notAProgress, isFalse);
    });

    test('toString が値を含むこと', () {
      final s = const TutorialProgress(currentPage: 1, totalPages: 5).toString();
      expect(s, contains('1'));
      expect(s, contains('5'));
    });
  });
}
