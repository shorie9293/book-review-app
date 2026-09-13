import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';
import 'package:book_review_app/features/import/domain/bulk_import_parser.dart';

/// 一括インポート1件ごとの結末。
enum ImportOutcome {
  /// 新規に蔵書へ追加した
  added,

  /// 既に蔵書に存在したため取り込みを見送った
  skippedExisting,

  /// 書誌情報が見つからなかった
  notFound,

  /// 書誌検索・保存で例外が発生した
  failed;

  /// 画面表示用のラベル
  String get label => switch (this) {
        ImportOutcome.added => '追加',
        ImportOutcome.skippedExisting => '登録済',
        ImportOutcome.notFound => '書誌なし',
        ImportOutcome.failed => '失敗',
      };
}

/// 一括インポート1件の処理結果。
class ImportRecord {
  final ImportEntry entry;
  final ImportOutcome outcome;
  final Book? book;
  final String? error;

  const ImportRecord({
    required this.entry,
    required this.outcome,
    this.book,
    this.error,
  });
}

/// 一括インポート全体の処理報告。
class BulkImportReport {
  final List<ImportRecord> records;

  const BulkImportReport(this.records);

  int _count(ImportOutcome outcome) => records.where((r) => r.outcome == outcome).length;

  /// 新規追加件数
  int get addedCount => _count(ImportOutcome.added);

  /// 既存重複で見送った件数
  int get skippedCount => _count(ImportOutcome.skippedExisting);

  /// 書誌が見つからなかった件数
  int get notFoundCount => _count(ImportOutcome.notFound);

  /// 例外で失敗した件数
  int get failedCount => _count(ImportOutcome.failed);

  /// 処理対象件数
  int get processedCount => records.length;

  /// 取り込むべき対象が無かったか
  bool get isEmpty => records.isEmpty;
}

/// ISBN 群を書誌検索して蔵書へ一括登録するオーケストレーション。
///
/// 純粋パーサの結果 [BulkImportParseResult] を受け取り、
/// 1. 既に蔵書にある ISBN はスキップ（重複登録の防止）
/// 2. 書誌検索でメタデータを取得（CSV で書名・著者が指定されていれば優先）
/// 3. 取得できたものを [BookRepository.addBook] で登録
/// という順で処理し、件ごとの結末を [BulkImportReport] に集約する。
class BulkImportService {
  final BookRepository repository;
  final BookSearchService searchService;

  /// 新規書籍の ID 生成関数（テストで固定値を注入可能）
  final String Function() idGenerator;

  BulkImportService({
    required this.repository,
    required this.searchService,
    String Function()? idGenerator,
  }) : idGenerator = idGenerator ?? _defaultIdGenerator;

  static int _sequence = 0;

  static String _defaultIdGenerator() {
    _sequence++;
    return 'import-${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }

  /// 解析結果のうち取り込み可能な行を順に処理する。
  ///
  /// [onProgress] は (処理済み件数, 総件数) で都度呼ばれる。
  Future<BulkImportReport> run(
    BulkImportParseResult parsed, {
    void Function(int done, int total)? onProgress,
  }) async {
    final targets = parsed.importable;
    final records = <ImportRecord>[];
    var done = 0;

    for (final entry in targets) {
      final existing = await repository.findByIsbn(entry.isbn);
      if (existing != null) {
        records.add(ImportRecord(entry: entry, outcome: ImportOutcome.skippedExisting, book: existing));
      } else {
        records.add(await _importOne(entry));
      }
      done++;
      onProgress?.call(done, targets.length);
    }

    return BulkImportReport(records);
  }

  Future<ImportRecord> _importOne(ImportEntry entry) async {
    try {
      final found = await searchService.searchByIsbn(entry.isbn);
      if (found == null) {
        return ImportRecord(entry: entry, outcome: ImportOutcome.notFound);
      }
      final book = Book(
        id: idGenerator(),
        title: _firstNonEmpty(entry.title, found.title),
        author: _firstNonEmpty(entry.author, found.author),
        isbn: entry.isbn,
        coverImageUrl: found.coverImageUrl,
        publisher: found.publisher,
        publishedDate: found.publishedDate,
        pageCount: found.pageCount,
        description: found.description,
      );
      await repository.addBook(book);
      return ImportRecord(entry: entry, outcome: ImportOutcome.added, book: book);
    } catch (e) {
      return ImportRecord(entry: entry, outcome: ImportOutcome.failed, error: '$e');
    }
  }

  static String _firstNonEmpty(String? preferred, String fallback) {
    if (preferred != null && preferred.trim().isNotEmpty) return preferred.trim();
    return fallback;
  }
}
