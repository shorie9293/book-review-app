import 'package:flutter/foundation.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/book_search_service.dart';
import 'package:book_review_app/features/import/domain/bulk_import_parser.dart';
import 'package:book_review_app/features/import/domain/bulk_import_service.dart';

/// 一括インポートの入力形式。
enum BulkImportMode {
  /// ISBN リストの貼り付け
  isbnList,

  /// CSV の貼り付け
  csv;

  /// 画面表示用のラベル
  String get label => switch (this) {
        BulkImportMode.isbnList => 'ISBNリスト',
        BulkImportMode.csv => 'CSV',
      };
}

/// 一括インポート画面のビジネスロジック。
///
/// 「解析（プレビュー）」と「取り込み（実行）」の2段階の状態を保持する。
class BulkImportViewModel extends ChangeNotifier {
  BulkImportMode _mode = BulkImportMode.isbnList;
  BulkImportParseResult? _preview;
  BulkImportReport? _report;
  bool _isImporting = false;
  int _progressDone = 0;
  int _progressTotal = 0;
  String? _errorMessage;

  BulkImportMode get mode => _mode;
  BulkImportParseResult? get preview => _preview;
  BulkImportReport? get report => _report;
  bool get isImporting => _isImporting;
  int get progressDone => _progressDone;
  int get progressTotal => _progressTotal;
  String? get errorMessage => _errorMessage;

  /// 入力形式を切り替えると解析結果を破棄する。
  void setMode(BulkImportMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _preview = null;
    _report = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// テキストを解析してプレビューを更新する。
  void parse(String text) {
    _report = null;
    _errorMessage = null;
    final result = switch (_mode) {
      BulkImportMode.isbnList => BulkImportParser.parseIsbnList(text),
      BulkImportMode.csv => BulkImportParser.parseCsv(text),
    };
    _preview = result.isEmpty ? null : result;
    if (result.isEmpty) {
      _errorMessage = '取り込める行がありませんでした';
    }
    notifyListeners();
  }

  /// 現在のプレビューの取込可能行を蔵書へ登録する。
  Future<void> runImport({
    required BookRepository repository,
    required BookSearchService searchService,
    BulkImportService? service,
  }) async {
    final preview = _preview;
    if (preview == null || !preview.hasImportable || _isImporting) return;

    _isImporting = true;
    _progressDone = 0;
    _progressTotal = preview.validCount;
    _errorMessage = null;
    notifyListeners();

    final runner = service ??
        BulkImportService(repository: repository, searchService: searchService);

    try {
      _report = await runner.run(
        preview,
        onProgress: (done, total) {
          _progressDone = done;
          _progressTotal = total;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = '取り込み中にエラーが発生しました: $e';
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  /// 解析・結果をすべて初期化する。
  void reset() {
    _preview = null;
    _report = null;
    _errorMessage = null;
    _isImporting = false;
    _progressDone = 0;
    _progressTotal = 0;
    notifyListeners();
  }
}
