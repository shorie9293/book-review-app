import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/backup/domain/backup_models.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';
import 'package:book_review_app/features/backup/domain/restore_preview.dart';

Book _book(String id, {String? title}) => Book(
      id: id,
      title: title ?? '本 $id',
      author: '著者',
      isbn: 'isbn-$id',
      addedAt: DateTime.utc(2026, 1, 1),
    );

Review _review(String id, String bookId) => Review(
      id: id,
      bookId: bookId,
      rating: 4,
      text: 'レビュー $id',
      createdAt: DateTime.utc(2026, 2, 2),
    );

BookNote _note(String id, String bookId) => BookNote(
      id: id,
      bookId: bookId,
      content: 'メモ $id',
      createdAt: DateTime.utc(2026, 3, 3),
    );

BackupBundle _bundle({
  List<Book> books = const [],
  List<Review> reviews = const [],
  List<BookNote> notes = const [],
}) =>
    BackupBundle(
      exportedAt: DateTime.utc(2026, 4, 4),
      books: books,
      reviews: reviews,
      notes: notes,
    );

void main() {
  group('RestorePreview.build', () {
    test('追加・重複の件数が merge の結果と一致する', () {
      final existing = _bundle(
        books: [_book('b1')],
        reviews: [_review('r1', 'b1')],
      );
      final incoming = _bundle(
        books: [_book('b1'), _book('b2'), _book('b3')],
        reviews: [_review('r1', 'b1')],
        notes: [_note('n1', 'b1')],
      );

      final preview = RestorePreview.build(incoming: incoming, existing: existing);

      expect(preview.booksAdded, 2);
      expect(preview.booksSkipped, 1);
      expect(preview.reviewsAdded, 0);
      expect(preview.reviewsSkipped, 1);
      expect(preview.notesAdded, 1);
      expect(preview.notesSkipped, 0);
      expect(preview.totalAdded, 3);
      expect(preview.totalSkipped, 2);
      expect(preview.total, 5);
      expect(preview.summary, '追加 3件 / スキップ 2件');
      expect(preview.hasAdditions, isTrue);
    });

    test('種別内訳が蔵書・レビュー・メモの順で並ぶ', () {
      final existing = _bundle(
        books: [_book('b1')],
        reviews: [_review('r1', 'b1')],
      );
      final incoming = _bundle(
        books: [_book('b1'), _book('b2'), _book('b3')],
        reviews: [_review('r1', 'b1')],
        notes: [_note('n1', 'b1')],
      );

      final preview = RestorePreview.build(incoming: incoming, existing: existing);

      expect(preview.breakdownLines, [
        '・蔵書: 追加 2冊 / 重複 1冊',
        '・レビュー: 追加 0件 / 重複 1件',
        '・メモ: 追加 1件 / 重複 0件',
      ]);
      expect(preview.breakdown, preview.breakdownLines.join('\n'));
    });

    test('サンプルは昇順で先頭5件、残りはほか表示になる', () {
      final existing = _bundle();
      // 入力順はわざと崩す（並びが入力順に依存しないことの確認）。
      final ids = ['b-07', 'b-02', 'b-05', 'b-01', 'b-04', 'b-06', 'b-03'];
      final incoming = _bundle(books: ids.map(_book).toList());

      final preview = RestorePreview.build(incoming: incoming, existing: existing);

      expect(preview.addedSamples.map((s) => s.id).toList(),
          ['b-01', 'b-02', 'b-03', 'b-04', 'b-05']);
      expect(preview.hiddenAddedCount, 2);
      final text = preview.samplesText;
      expect(text, isNotNull);
      expect(text, contains('追加されるデータ（先頭 5件）:'));
      expect(text, contains('・蔵書「本 b-01」'));
      expect(text, contains('ほか 2件'));
      expect(text, isNot(contains('本 b-06')));
    });

    test('追加0件なら「追加されるデータはありません」を出す', () {
      final existing = _bundle(
        books: [_book('b1')],
        reviews: [_review('r1', 'b1')],
      );
      final incoming = _bundle(
        books: [_book('b1')],
        reviews: [_review('r1', 'b1')],
      );

      final preview = RestorePreview.build(incoming: incoming, existing: existing);

      expect(preview.totalAdded, 0);
      expect(preview.hasAdditions, isFalse);
      expect(preview.summary, '追加 0件 / スキップ 2件');
      expect(preview.message, contains('追加されるデータはありません'));
      expect(preview.samplesText, isNull);
    });

    test('空バックアップなら「復元するデータはありません」を出す', () {
      final preview = RestorePreview.build(
        incoming: _bundle(),
        existing: _bundle(books: [_book('b1')]),
      );

      expect(preview.total, 0);
      expect(preview.message, '復元するデータはありません');
      expect(preview.breakdown, contains('・蔵書: 追加 0冊 / 重複 0冊'));
      expect(preview.samplesText, isNull);
    });

    test('追加があるときは既存優先（上書きしない）の一文を出す', () {
      final preview = RestorePreview.build(
        incoming: _bundle(books: [_book('b9')]),
        existing: _bundle(books: [_book('b1')]),
      );

      expect(preview.message, '既存データは上書きされません（追加のみ行われます）');
      expect(preview.message, isNot(contains('上書きされます')));
    });

    test('incoming 内の重複idは先勝ちで畳む', () {
      final preview = RestorePreview.build(
        incoming: _bundle(books: [_book('b2', title: '先'), _book('b2', title: '後')]),
        existing: _bundle(),
      );

      expect(preview.booksAdded, 1);
      expect(preview.booksSkipped, 1);
      expect(preview.addedSamples, hasLength(1));
      expect(preview.addedSamples.single.label, '先');
    });

    test('長い見出しは抜粋して1行に収める', () {
      final longTitle = 'あ' * 80;
      final preview = RestorePreview.build(
        incoming: _bundle(books: [_book('b1', title: longTitle)]),
        existing: _bundle(),
      );

      final label = preview.addedSamples.single.label;
      expect(label.endsWith('…'), isTrue);
      expect(label.length, lessThan(longTitle.length));
    });

    test('sampleLimit 0 / 負値でも throw しない', () {
      final incoming = _bundle(books: [_book('b1'), _book('b2')]);
      final existing = _bundle();

      final zero = RestorePreview.build(
        incoming: incoming,
        existing: existing,
        sampleLimit: 0,
      );
      final negative = RestorePreview.build(
        incoming: incoming,
        existing: existing,
        sampleLimit: -3,
      );

      expect(zero.addedSamples, isEmpty);
      expect(zero.hiddenAddedCount, 2);
      expect(zero.samplesText, isNull);
      expect(negative.addedSamples, isEmpty);
      expect(negative.hiddenAddedCount, 2);
      // 件数表示は sampleLimit に影響されない
      expect(zero.summary, '追加 2件 / スキップ 0件');
    });
  });

  group('RestorePreview.tryBuildFromJson', () {
    final existing = _bundle(books: [_book('b1')]);

    test('正常なJSONはプレビューを返す', () {
      final json = const BackupService().exportJson(
        _bundle(books: [_book('b1'), _book('b2')]),
      );

      final preview = RestorePreview.tryBuildFromJson(json: json, existing: existing);

      expect(preview, isNotNull);
      expect(preview!.booksAdded, 1);
      expect(preview.booksSkipped, 1);
    });

    test('破損JSONは null を返し例外を投げない', () {
      late RestorePreview? preview;
      expect(
        () => preview =
            RestorePreview.tryBuildFromJson(json: '{broken json', existing: existing),
        returnsNormally,
      );
      expect(preview, isNull);
    });

    test('空文字・null は null', () {
      expect(
        RestorePreview.tryBuildFromJson(json: '', existing: existing),
        isNull,
      );
      expect(
        RestorePreview.tryBuildFromJson(json: null, existing: existing),
        isNull,
      );
    });

    test('非オブジェクトJSON（配列・数値）は null', () {
      expect(
        RestorePreview.tryBuildFromJson(json: '[1,2,3]', existing: existing),
        isNull,
      );
      expect(
        RestorePreview.tryBuildFromJson(json: '42', existing: existing),
        isNull,
      );
    });

    test('スキーマ不一致（必須欠落）は null', () {
      expect(
        RestorePreview.tryBuildFromJson(
          json: '{"schemaVersion":1}',
          existing: existing,
        ),
        isNull,
      );
    });

    test('巨大入力（2万件）でも throw せず先頭5件に絞る', () {
      final books = List<Book>.generate(20000, (i) => _book('big-$i'));
      final json = const BackupService().exportJson(_bundle(books: books));

      final preview = RestorePreview.tryBuildFromJson(
        json: json,
        existing: _bundle(),
      );

      expect(preview, isNotNull);
      expect(preview!.booksAdded, 20000);
      expect(preview.addedSamples, hasLength(5));
      expect(preview.hiddenAddedCount, 19995);
    });
  });
}
