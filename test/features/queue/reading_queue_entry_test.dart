import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/reading_queue_entry.dart';

void main() {
  final now = DateTime(2026, 9, 18, 10);
  ReadingQueueEntry entry(String bookId, int position, [DateTime? at]) =>
      ReadingQueueEntry(bookId: bookId, position: position, addedAt: at ?? now);

  group('ReadingQueueEntry コンストラクタ検証', () {
    test('position < 1 は ArgumentError（非const本体）', () {
      expect(() => entry('b1', 0), throwsArgumentError);
    });

    test('負の position も ArgumentError', () {
      expect(() => entry('b1', -5), throwsArgumentError);
    });

    test('空文字 bookId は ArgumentError', () {
      expect(() => entry('', 1), throwsArgumentError);
    });

    test('正常なエントリは生成できる', () {
      final e = entry('b1', 1);
      expect(e.bookId, 'b1');
      expect(e.position, 1);
      expect(e.addedAt, now);
    });
  });

  group('ReadingQueueEntry copyWith', () {
    test('position を変更できる', () {
      final e = entry('b1', 1).copyWith(position: 3);
      expect(e.position, 3);
      expect(e.bookId, 'b1');
    });

    test('addedAt を変更できる', () {
      final later = now.add(const Duration(hours: 1));
      final e = entry('b1', 1).copyWith(addedAt: later);
      expect(e.addedAt, later);
    });
  });

  group('ReadingQueueEntry JSON往復', () {
    test('toJson/fromJson で値等価', () {
      final e = entry('b1', 2);
      final restored = ReadingQueueEntry.fromJson(e.toJson());
      expect(restored, e);
      expect(restored.addedAt, e.addedAt);
    });

    test('bookId 欠落は FormatException', () {
      expect(() => ReadingQueueEntry.fromJson({'position': 1,
          'addedAt': now.toIso8601String()}), throwsFormatException);
    });

    test('position 型不一致は FormatException', () {
      expect(
        () => ReadingQueueEntry.fromJson({
          'bookId': 'b1',
          'position': 'one',
          'addedAt': now.toIso8601String(),
        }),
        throwsFormatException,
      );
    });

    test('position 0 は FormatException', () {
      expect(
        () => ReadingQueueEntry.fromJson({
          'bookId': 'b1',
          'position': 0,
          'addedAt': now.toIso8601String(),
        }),
        throwsFormatException,
      );
    });

    test('addedAt 不正は FormatException', () {
      expect(
        () => ReadingQueueEntry.fromJson(
            {'bookId': 'b1', 'position': 1, 'addedAt': 'not-a-date'}),
        throwsFormatException,
      );
    });
  });

  group('ReadingQueueEntry 値等価', () {
    test('同値は == / 同一 hashCode', () {
      final a = entry('b1', 1);
      final b = entry('b1', 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('position が違えば非等価', () {
      expect(entry('b1', 1) == entry('b1', 2), isFalse);
    });
  });
}
