import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/reading_status.dart';

void main() {
  group('ReadingStatus', () {
    test('積読/読書中/読了の3状態を持つ', () {
      expect(ReadingStatus.values, hasLength(3));
      expect(ReadingStatus.values, containsAll([
        ReadingStatus.unread,
        ReadingStatus.reading,
        ReadingStatus.finished,
      ]));
    });

    test('日本語ラベルを返す', () {
      expect(ReadingStatus.unread.label, '積読');
      expect(ReadingStatus.reading.label, '読書中');
      expect(ReadingStatus.finished.label, '読了');
    });

    test('fromStorage は未知値/非文字列に積読を返す（後方互換）', () {
      expect(ReadingStatus.fromStorage(null), ReadingStatus.unread);
      expect(ReadingStatus.fromStorage(42), ReadingStatus.unread);
      expect(ReadingStatus.fromStorage('unknown'), ReadingStatus.unread);
      expect(ReadingStatus.fromStorage('reading'), ReadingStatus.reading);
    });
  });
}
