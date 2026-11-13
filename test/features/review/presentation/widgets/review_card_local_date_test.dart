import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/notes/presentation/widgets/note_card.dart';
import 'package:book_review_app/features/review/presentation/widgets/review_card.dart';

/// 保存形式（末尾 'Z' = UTC 種別の瞬間）を渡したとき、カードの日付表示が
/// **その瞬間のローカル暦** になることを固定する。
///
/// 期待値は必ず `.toLocal()` から算出する（JST 決め打ち禁止）。
/// TZ=UTC の CI でも TZ=Asia/Tokyo でも同じ式で成立する。
void main() {
  /// ローカル暦の `yyyy/M/d`（ゼロ埋めなし）— 期待値算出専用。
  String expectedLocalDate(DateTime instant) {
    final local = instant.toLocal();
    return '${local.year}/${local.month}/${local.day}';
  }

  /// UTC 暦の `yyyy/M/d` — 「UTC 直読みの誤表示」検出用。
  String utcDate(DateTime instant) {
    final utc = instant.toUtc();
    return '${utc.year}/${utc.month}/${utc.day}';
  }

  Future<void> pumpReviewCard(WidgetTester tester, DateTime createdAt) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewCard(
            review: Review(
              id: 'r1',
              bookId: 'book1',
              rating: 4,
              text: '早朝に読了した。',
              createdAt: createdAt,
            ),
            onDelete: () {},
            onEdit: () {},
          ),
        ),
      ),
    );
  }

  Future<void> pumpNoteCard(WidgetTester tester, DateTime createdAt) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(
            note: BookNote(
              id: 'n1',
              bookId: 'book1',
              kind: NoteKind.memo,
              content: '早朝の気づき',
              createdAt: createdAt,
            ),
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );
  }

  group('ReviewCard の日付はローカル暦で表示される', () {
    testWidgets('Z付き文字列（UTC種別）でもその瞬間のローカル暦を表示する',
        (tester) async {
      final instant = DateTime.parse('2026-10-31T15:05:00.000Z');
      expect(instant.isUtc, isTrue, reason: '前提: Z付きは UTC 種別');

      await pumpReviewCard(tester, instant);

      final dateText = tester.widget<Text>(
        find.byKey(const Key('review_card_date')),
      );
      expect(dateText.data, expectedLocalDate(instant));
    });

    testWidgets('UTC 暦を直読みした場合の表示にはならない', (tester) async {
      final instant = DateTime.parse('2026-10-31T15:05:00.000Z');
      await pumpReviewCard(tester, instant);

      // ローカル暦と UTC 暦が食い違う TZ（例: Asia/Tokyo）でのみ意味を持つ。
      if (expectedLocalDate(instant) != utcDate(instant)) {
        expect(find.text(utcDate(instant)), findsNothing);
      }
      expect(find.text(expectedLocalDate(instant)), findsOneWidget);
    });

    testWidgets('ローカル種別の日時は従来どおりゼロ埋めなしで表示する',
        (tester) async {
      await pumpReviewCard(tester, DateTime(2025, 3, 15));

      expect(find.text('2025/3/15'), findsOneWidget);
    });
  });

  group('NoteCard の日付はローカル暦で表示される', () {
    testWidgets('Z付き文字列（UTC種別）でもその瞬間のローカル暦を表示する',
        (tester) async {
      final instant = DateTime.parse('2026-10-31T15:05:00.000Z');
      expect(instant.isUtc, isTrue);

      await pumpNoteCard(tester, instant);

      final dateText = tester.widget<Text>(
        find.byKey(const Key('note_card_date')),
      );
      expect(dateText.data, expectedLocalDate(instant));
    });

    testWidgets('UTC 暦を直読みした場合の表示にはならない', (tester) async {
      final instant = DateTime.parse('2026-10-31T15:05:00.000Z');
      await pumpNoteCard(tester, instant);

      if (expectedLocalDate(instant) != utcDate(instant)) {
        expect(find.text(utcDate(instant)), findsNothing);
      }
      expect(find.text(expectedLocalDate(instant)), findsOneWidget);
    });
  });
}
