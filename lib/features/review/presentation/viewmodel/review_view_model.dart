import 'package:flutter/foundation.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';

/// レビュー画面のビジネスロジックを管理する ViewModel。
///
/// レビューの読み込み・追加・編集・削除の状態と操作をカプセル化する。
class ReviewViewModel extends ChangeNotifier {
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;

  List<Review> get reviews => List.unmodifiable(_reviews);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 指定書籍のレビュー一覧を読み込む
  Future<void> loadReviews(ReviewRepository repository, String bookId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reviews = await repository.getReviewsByBookId(bookId);
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// レビューを追加する
  Future<void> addReview(ReviewRepository repository, Review review) async {
    await repository.addReview(review);
    await _reloadAfterMutation(repository, review.bookId);
  }

  /// レビューを更新する
  Future<void> updateReview(ReviewRepository repository, Review review) async {
    await repository.updateReview(review);
    await _reloadAfterMutation(repository, review.bookId);
  }

  /// レビューを削除する
  Future<void> deleteReview(ReviewRepository repository, String id) async {
    // We need bookId for reload, get it from current list
    final review = _reviews.firstWhere((r) => r.id == id);
    await repository.deleteReview(id);
    await _reloadAfterMutation(repository, review.bookId);
  }

  Future<void> _reloadAfterMutation(
      ReviewRepository repository, String bookId) async {
    _reviews = await repository.getReviewsByBookId(bookId);
    notifyListeners();
  }
}
