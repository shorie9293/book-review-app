import 'package:flutter/foundation.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/stats/domain/reading_stats_service.dart';

/// 統計算出に必要なデータ源の抽象インターフェース。
///
/// 既存リポジトリを合成する（HiveBookRepository + HiveChallengeRepository）。
/// テスト時は Fake で差し替え可能。
abstract class StatsDataSource {
  Future<List<Book>> getBooks();
  Future<List<Review>> getAllReviews();
}

/// 読書統計画面の状態を管理する ViewModel。
class StatsViewModel extends ChangeNotifier {
  ReadingStats? _stats;
  bool _isLoading = true;
  String? _error;

  /// 算出済みの統計（読み込み完了まで null）
  ReadingStats? get stats => _stats;

  /// 読み込み中か
  bool get isLoading => _isLoading;

  /// 読み込み失敗時のエラー（成功時は null）
  String? get error => _error;

  /// データ源から蔵書・レビューを読み込み統計を算出する。
  Future<void> load(StatsDataSource source) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final books = await source.getBooks();
      final reviews = await source.getAllReviews();
      _stats = ReadingStatsService.compute(books: books, reviews: reviews);
    } catch (e) {
      _stats = null;
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }
}
