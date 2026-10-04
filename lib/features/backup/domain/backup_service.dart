import 'dart:convert';

import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/backup/domain/backup_models.dart';

/// エクスポート／バックアップのドメインサービス。
///
/// JSON 整形・パース・マージ・CSV エクスポートを担う。
/// UI・永続化には関与しない（純粋な JSON 整形とリポジトリ操作に徹する）。
class BackupService {
  final DateTime Function() _now;

  /// [now] を注入できる（既定は [DateTime.now]）。
  const BackupService({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// 対象データから [BackupBundle] を組み立てる（exportedAt は UTC）。
  BackupBundle build({
    required List<Book> books,
    required List<Review> reviews,
    required List<BookNote> notes,
  }) {
    return BackupBundle(
      exportedAt: _now().toUtc(),
      books: List.unmodifiable(books),
      reviews: List.unmodifiable(reviews),
      notes: List.unmodifiable(notes),
    );
  }

  /// 整形JSON（2スペースインデント）へ書き出す。
  String exportJson(BackupBundle bundle) {
    return const JsonEncoder.withIndent('  ').convert(bundle.toJson());
  }

  /// 整形JSONをパースして [BackupBundle] に復元する。
  ///
  /// 破損JSON・非オブジェクト・必須欠落は [FormatException]。
  BackupBundle parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      rethrow;
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup JSON must be an object');
    }
    return BackupBundle.fromJson(decoded);
  }

  /// 受け取った [incoming] を既存データへマージする。
  ///
  /// - 既存id に無い要素だけを「追加」とし、既存は上書きしない（既存優先）
  /// - incoming 内の重複id も1件に畳む
  /// - skipped = incoming総数（畳み込み後） - added
  BackupMergeResult merge({
    required BackupBundle incoming,
    required List<Book> existingBooks,
    required List<Review> existingReviews,
    required List<BookNote> existingNotes,
  }) {
    final existingBookIds = existingBooks.map((b) => b.id).toSet();
    final existingReviewIds = existingReviews.map((r) => r.id).toSet();
    final existingNoteIds = existingNotes.map((n) => n.id).toSet();

    final booksToAdd = _uniqueById(incoming.books)
        .where((b) => !existingBookIds.contains(b.id))
        .toList();
    final reviewsToAdd = _uniqueById(incoming.reviews)
        .where((r) => !existingReviewIds.contains(r.id))
        .toList();
    final notesToAdd = _uniqueById(incoming.notes)
        .where((n) => !existingNoteIds.contains(n.id))
        .toList();

    return BackupMergeResult(
      booksAdded: booksToAdd.length,
      reviewsAdded: reviewsToAdd.length,
      notesAdded: notesToAdd.length,
      booksSkipped: incoming.books.length - booksToAdd.length,
      reviewsSkipped: incoming.reviews.length - reviewsToAdd.length,
      notesSkipped: incoming.notes.length - notesToAdd.length,
    );
  }

  /// 蔵書一覧を RFC4180 準拠の CSV へ書き出す（行末は改行）。
  static String exportBooksCsv(List<Book> books) {
    const header =
        'id,title,author,isbn,genres,readingStatus,currentPage,pageCount,addedAt,finishedAt';
    final buffer = StringBuffer(header);
    for (final book in books) {
      buffer
        ..write('\n')
        ..write(_escape(book.id))
        ..write(',')
        ..write(_escape(book.title))
        ..write(',')
        ..write(_escape(book.author))
        ..write(',')
        ..write(_escape(book.isbn))
        ..write(',')
        ..write(_escape(book.genres.join(';')))
        ..write(',')
        ..write(_escape(book.readingStatus.name))
        ..write(',')
        ..write(_escape('${book.currentPage}'))
        ..write(',')
        ..write(_escape('${book.pageCount ?? ''}'))
        ..write(',')
        ..write(_escape('${book.addedAt?.toIso8601String() ?? ''}'))
        ..write(',')
        ..write(_escape('${book.finishedAt?.toIso8601String() ?? ''}'));
    }
    buffer.write('\n');
    return buffer.toString();
  }

  /// incoming 内の重複id を畳む（先勝ち、順序保持）。
  List<T> _uniqueById<T>(List<T> items) {
    final seen = <Object?>{};
    return [
      for (final item in items)
        if (seen.add((item as dynamic).id)) item,
    ];
  }

  /// RFC4180 準拠の CSV エスケープ。
  ///
  /// `"` → `""`、`,` / `"` / 改行 を含む値は `"` で囲む。
  static String _escape(String value) {
    final needsQuote =
        value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
    if (!needsQuote) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
