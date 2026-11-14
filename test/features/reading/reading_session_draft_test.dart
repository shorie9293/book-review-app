import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/reading/domain/reading_session_draft.dart';

void main() {
  group('ReadingSessionDraft', () {
    test('toJson は UTC 瞬間の ISO8601 文字列で保存する', () {
      final draft = ReadingSessionDraft(
        startedAt: DateTime.utc(2026, 10, 4, 3, 0),
      );

      final json = draft.toJson();

      expect(json['startedAt'], '2026-10-04T03:00:00.000Z');
    });

    test('ローカル時刻で作っても保存は UTC に正規化される', () {
      final local = DateTime(2026, 10, 4, 12, 0);
      final json = ReadingSessionDraft(startedAt: local).toJson();

      // 暦を読み替えず、同じ瞬間を UTC で表す。
      expect(json['startedAt'], local.toUtc().toIso8601String());
      expect(json['startedAt'] as String, endsWith('Z'));
    });

    test('JSON 往復で同じ瞬間に戻る', () {
      final original = ReadingSessionDraft(
        startedAt: DateTime.utc(2026, 10, 4, 3, 0),
      );

      final restored = ReadingSessionDraft.tryFromJson(original.toJson());

      expect(restored, isNotNull);
      expect(restored!.startedAt, original.startedAt);
      expect(restored.startedAt.isUtc, isTrue);
    });

    test('キー欠損は null（throw しない）', () {
      expect(ReadingSessionDraft.tryFromJson(<String, dynamic>{}), isNull);
    });

    test('型違い・壊れ値は null（throw しない）', () {
      expect(ReadingSessionDraft.tryFromJson(null), isNull);
      expect(ReadingSessionDraft.tryFromJson('文字列'), isNull);
      expect(ReadingSessionDraft.tryFromJson(123), isNull);
      expect(ReadingSessionDraft.tryFromJson(<String, dynamic>{'startedAt': 1}),
          isNull);
      expect(
          ReadingSessionDraft.tryFromJson(<String, dynamic>{'startedAt': null}),
          isNull);
      expect(
          ReadingSessionDraft.tryFromJson(
              <String, dynamic>{'startedAt': 'ぜんぜん日時ではない'}),
          isNull);
      expect(
          ReadingSessionDraft.tryFromJson(
              <String, dynamic>{'startedAt': '2026-10-04T'}),
          isNull);
      expect(
          ReadingSessionDraft.tryFromJson(
              <String, dynamic>{'startedAt': '2026-10-04T99'}),
          isNull);
      expect(
          ReadingSessionDraft.tryFromJson(
              <String, dynamic>{'startedAt': '2026-13-45T99:99:99Z'}),
          isNull);
      // 正準形（ミリ秒付き UTC）以外は受け入れない
      expect(
          ReadingSessionDraft.tryFromJson(
              <String, dynamic>{'startedAt': '2026-10-04T03:00:00Z'}),
          isNull);
    });

    test('elapsedMinutes は最低1分でクランプする', () {
      final startedAt = DateTime.utc(2026, 10, 4, 3, 0);
      final draft = ReadingSessionDraft(startedAt: startedAt);

      // 0秒・90秒はどちらも1分
      expect(draft.elapsedMinutes(startedAt), 1);
      expect(
          draft.elapsedMinutes(startedAt.add(const Duration(seconds: 90))), 1);
      // 5分ちょうど
      expect(
          draft.elapsedMinutes(startedAt.add(const Duration(minutes: 5))), 5);
    });

    test('未来時刻・時計巻き戻りでも throw せず 1 を返す', () {
      final startedAt = DateTime.utc(2026, 10, 4, 3, 0);
      final draft = ReadingSessionDraft(startedAt: startedAt);

      expect(
          draft.elapsedMinutes(startedAt.subtract(const Duration(days: 2))), 1);
      expect(draft.elapsedMinutes(DateTime.utc(2000, 1, 1)), 1);
    });

    test('同じ開始時刻どうしは等価', () {
      final at = DateTime.utc(2026, 10, 4, 3, 0);
      expect(ReadingSessionDraft(startedAt: at),
          ReadingSessionDraft(startedAt: at));
      expect(ReadingSessionDraft(startedAt: at).hashCode,
          ReadingSessionDraft(startedAt: at).hashCode);
    });
  });
}
