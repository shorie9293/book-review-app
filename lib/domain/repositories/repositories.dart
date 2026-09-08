import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';

/// 書籍リポジトリの抽象インターフェース
///
/// 蔵書（本棚）の読み取り・追加・削除操作を定義する。
/// Feature層の具象実装に差し替え可能（テスト時はMockで代替）。
abstract class BookRepository {
  /// 蔵書一覧を取得する
  Future<List<Book>> getBooks();

  /// 指定IDの書籍を取得する（存在しない場合はnull）
  Future<Book?> getBookById(String id);

  /// ISBNから書籍を検索する（存在しない場合はnull）
  Future<Book?> findByIsbn(String isbn);

  /// 書籍を蔵書に追加する
  Future<void> addBook(Book book);

  /// 書籍を蔵書から削除する
  Future<void> removeBook(String id);
}

/// レビューリポジトリの抽象インターフェース
///
/// 書籍レビューの読み取り・追加・更新・削除操作を定義する。
abstract class ReviewRepository {
  /// 指定書籍の全レビューを取得する
  Future<List<Review>> getReviewsByBookId(String bookId);

  /// レビューを追加する
  Future<void> addReview(Review review);

  /// レビューを更新する
  Future<void> updateReview(Review review);

  /// レビューを削除する
  Future<void> deleteReview(String id);
}

/// 年間読書チャレンジリポジトリの抽象インターフェース
///
/// 年間目標冊数の永続化と、進捗算出に必要な全レビュー一覧の取得を担う。
/// 具象実装は Hive（[ChallengeRepository]）に差し替え可能（テスト時はMockで代替）。
abstract class ChallengeRepository {
  /// 年間目標冊数を取得する（未設定の場合は 0）
  Future<int> getAnnualTarget();

  /// 年間目標冊数を設定する（負値は 0 として保存）
  Future<void> setAnnualTarget(int target);

  /// 全書籍の全レビュー一覧を取得する
  Future<List<Review>> getAllReviews();
}
