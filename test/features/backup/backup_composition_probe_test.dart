import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/reading_status.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';

/// 親探針（合成の不変条件）。
///
/// 眷属は個別操作を撃ちがちなので、親が「collect → exportJson → parse → restore」
/// の往復合成と、既存上書き禁止・冪等性という不変条件を独自データで撃つ。
Book _book(String id, String title) => Book(
      id: id,
      title: title,
      author: '著者$id',
      isbn: '978000000$id',
      genres: const ['小説'],
      readingStatus: ReadingStatus.finished,
      currentPage: 100,
      pageCount: 100,
    );

Review _review(String id, String bookId) => Review(
      id: id,
      bookId: bookId,
      rating: 4,
      text: 'レビュー$id',
      createdAt: DateTime.utc(2026, 1, 1),
    );

BookNote _note(String id, String bookId) => BookNote(
      id: id,
      bookId: bookId,
      content: 'メモ$id',
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  const service = BackupService();

  test('合成: collect→exportJson→parse→restore の往復で全件が保たれる', () async {
    final source = InMemoryBackupRepository(
      books: [_book('b1', '本1'), _book('b2', '本2')],
      reviews: [_review('r1', 'b1'), _review('r2', 'b2')],
      notes: [_note('n1', 'b1'), _note('n2', 'b2')],
    );
    final bundle = await source.collect();

    // 別インスタンスで JSON 経由の復元（画面のコピー＆ペースト経路に相当）
    final json = service.exportJson(bundle);
    final parsed = service.parse(json);

    final target = InMemoryBackupRepository(books: [], reviews: [], notes: []);
    final result = await target.restore(parsed);

    expect(result.booksAdded, 2);
    expect(result.reviewsAdded, 2);
    expect(result.notesAdded, 2);
    expect(result.totalSkipped, 0);
    expect(target.books.map((b) => b.id), ['b1', 'b2']);
    expect(target.reviews.map((r) => r.id), ['r1', 'r2']);
    expect(target.notes.map((n) => n.id), ['n1', 'n2']);
  });

  test('冪等: 同じバンドルを2回復元しても2回目は全件スキップされる', () async {
    final json = service.exportJson(service.build(
      books: [_book('b1', '本1')],
      reviews: [_review('r1', 'b1')],
      notes: [_note('n1', 'b1')],
    ));
    final bundle = service.parse(json);

    final target = InMemoryBackupRepository(books: [], reviews: [], notes: []);
    final first = await target.restore(bundle);
    final second = await target.restore(bundle);

    expect(first.totalAdded, 3);
    expect(second.totalAdded, 0);
    expect(second.totalSkipped, 3);
    expect(target.books.length, 1);
    expect(target.reviews.length, 1);
    expect(target.notes.length, 1);
  });

  test('既存優先: 同一idの既存データは復元で上書きされない（静かな上書きを撃つ）', () async {
    final existing = _book('b1', '既存の題');
    final target = InMemoryBackupRepository(
      books: [existing],
      reviews: [],
      notes: [],
    );
    final bundle = service.build(
      books: [_book('b1', '復元側の別題')],
      reviews: const [],
      notes: const [],
    );

    await target.restore(bundle);

    expect(target.books.length, 1);
    expect(target.books.single.title, '既存の題');
  });

  test('CSV: 区切り・引用符・改行を含む書名でも列数が崩れない', () {
    final csv = BackupService.exportBooksCsv([
      _book('b1', 'カンマ,含む'),
      _book('b2', '引用"符'),
      _book('b3', '改行\n含む'),
    ]);
    final lines = csv.split('\n');
    // ヘッダ + 3行（改行入りタイトルは引用されるため論理行は3）
    expect(lines.first.split(',').length, 10);
    expect(csv.contains('"カンマ,含む"'), isTrue);
    expect(csv.contains('"引用""符"'), isTrue);
    expect(csv.contains('"改行\n含む"'), isTrue);
  });
}
