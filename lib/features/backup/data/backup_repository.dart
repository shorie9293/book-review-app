import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/backup/data/backup_settings_store.dart';
import 'package:book_review_app/features/backup/domain/backup_models.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';
import 'package:book_review_app/features/backup/domain/backup_settings_spec.dart';

/// エクスポート／リストアの永続化インターフェース。
///
/// collect で現状を束ね、restore でバンドルを既存データへ安全に足し込む。
abstract class BackupRepository {
  /// 現在の蔵書・レビュー・メモ（と設定）をまとめて採取する。
  Future<BackupBundle> collect();

  /// バンドルを既存データへマージして書き戻す（既存優先・上書きしない）。
  ///
  /// [includeSettings] が false なら控えの設定（テーマ・文字サイズ等）は
  /// 適用しない（記録のマージだけを行う）。
  Future<BackupMergeResult> restore(
    BackupBundle bundle, {
    bool includeSettings = true,
  });
}

/// 既存の Hive リポジトリを束ねた [BackupRepository] 実装。
class HiveBackupRepository implements BackupRepository {
  final BookRepository _bookRepo;
  final ReviewRepository _reviewRepo;
  final BookNoteRepository _noteRepo;

  /// 設定の生値の読み書き先（未指定なら Hive 実装）。
  final BackupSettingsStore _settingsStore;

  HiveBackupRepository({
    required BookRepository bookRepository,
    required ReviewRepository reviewRepository,
    required BookNoteRepository noteRepository,
    BackupSettingsStore? settingsStore,
  })  : _bookRepo = bookRepository,
        _reviewRepo = reviewRepository,
        _noteRepo = noteRepository,
        _settingsStore = settingsStore ?? const HiveBackupSettingsStore();

  @override
  Future<BackupBundle> collect() async {
    final books = await _bookRepo.getBooks();
    final reviews = <Review>[];
    for (final book in books) {
      reviews.addAll(await _reviewRepo.getReviewsByBookId(book.id));
    }
    final notes = await _noteRepo.getAllNotes();
    return BackupBundle(
      exportedAt: DateTime.now().toUtc(),
      books: books,
      reviews: reviews,
      notes: notes,
      settings: await _collectSettings(),
    );
  }

  /// 設定を許可リスト経由で束ねる（未保存・読取不能なら null）。
  Future<BackupSettingsBundle?> _collectSettings() async {
    try {
      final values = selectForBackup(await _settingsStore.readRaw());
      if (values.isEmpty) return null;
      return BackupSettingsBundle(values: values);
    } catch (_) {
      // 設定は任意項目。読めなくても控え本体は作る。
      return null;
    }
  }

  @override
  Future<BackupMergeResult> restore(
    BackupBundle bundle, {
    bool includeSettings = true,
  }) async {
    final existingBooks = await _bookRepo.getBooks();
    final existingNotes = await _noteRepo.getAllNotes();
    final existingReviews = <Review>[];
    for (final book in existingBooks) {
      existingReviews.addAll(await _reviewRepo.getReviewsByBookId(book.id));
    }

    final merge = const BackupService().merge(
      incoming: bundle,
      existingBooks: existingBooks,
      existingReviews: existingReviews,
      existingNotes: existingNotes,
    );

    // 追加対象のみを書き戻す（既存id は上書きしない）
    final existingBookIds = existingBooks.map((b) => b.id).toSet();
    final existingReviewIds = existingReviews.map((r) => r.id).toSet();
    final existingNoteIds = existingNotes.map((n) => n.id).toSet();
    final seenBookIds = <String>{};
    final seenReviewIds = <String>{};
    final seenNoteIds = <String>{};

    for (final book in bundle.books) {
      if (!seenBookIds.add(book.id)) continue;
      if (existingBookIds.contains(book.id)) continue;
      await _bookRepo.addBook(book);
    }
    for (final review in bundle.reviews) {
      if (!seenReviewIds.add(review.id)) continue;
      if (existingReviewIds.contains(review.id)) continue;
      await _reviewRepo.addReview(review);
    }
    for (final note in bundle.notes) {
      if (!seenNoteIds.add(note.id)) continue;
      if (existingNoteIds.contains(note.id)) continue;
      await _noteRepo.addNote(note);
    }
    if (includeSettings) {
      await _applySettings(bundle.settings);
    }
    return merge;
  }

  /// 控えの設定を適用する（未知キー無視・型不一致は個別に握る）。
  ///
  /// 記録の適用後に呼ぶ。設定の失敗は復元結果を落とさない。
  Future<void> _applySettings(BackupSettingsBundle? settings) async {
    if (settings == null || settings.values.isEmpty) return;
    try {
      await _settingsStore.writeValues(settings.values);
    } catch (_) {
      // 設定は「あれば得する」任意項目。失敗しても記録の復元は成功扱い。
    }
  }
}

/// テスト・プレビュー用のインメモリ [BackupRepository] 実装。
///
/// 注入したリストそのものへ追記する（restore は追加分のみ足し込む）。
class InMemoryBackupRepository implements BackupRepository {
  final List<Book> books;
  final List<Review> reviews;
  final List<BookNote> notes;

  InMemoryBackupRepository({
    required this.books,
    required this.reviews,
    required this.notes,
  });

  @override
  Future<BackupBundle> collect() async {
    return BackupBundle(
      exportedAt: DateTime.now().toUtc(),
      books: List.of(books),
      reviews: List.of(reviews),
      notes: List.of(notes),
    );
  }

  @override
  Future<BackupMergeResult> restore(
    BackupBundle bundle, {
    bool includeSettings = true,
  }) async {
    final merge = const BackupService().merge(
      incoming: bundle,
      existingBooks: books,
      existingReviews: reviews,
      existingNotes: notes,
    );

    final existingBookIds = books.map((b) => b.id).toSet();
    final existingReviewIds = reviews.map((r) => r.id).toSet();
    final existingNoteIds = notes.map((n) => n.id).toSet();

    for (final book in bundle.books) {
      if (existingBookIds.contains(book.id)) continue;
      books.add(book);
      existingBookIds.add(book.id);
    }
    for (final review in bundle.reviews) {
      if (existingReviewIds.contains(review.id)) continue;
      reviews.add(review);
      existingReviewIds.add(review.id);
    }
    for (final note in bundle.notes) {
      if (existingNoteIds.contains(note.id)) continue;
      notes.add(note);
      existingNoteIds.add(note.id);
    }
    return merge;
  }
}
