import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'dart:convert';

/// Hive を使用した ReviewRepository の実装
class HiveReviewRepository implements ReviewRepository {
  late Box<String> _box;

  /// 初期化（テスト時は明示的に呼び出す）
  Future<void> init({String? boxName}) async {
    _box = await Hive.openBox<String>(boxName ?? 'reviews');
  }

  /// テスト用：ボックスをクリアする
  Future<void> clear() async {
    await _box.clear();
  }

  /// ボックスを閉じる
  Future<void> close() async {
    await _box.close();
  }

  /// ReviewモデルをJSON文字列に変換
  String _reviewToJson(Review review) {
    return json.encode({
      'id': review.id,
      'bookId': review.bookId,
      'rating': review.rating,
      'text': review.text,
      'createdAt': review.createdAt.toIso8601String(),
      'updatedAt': review.updatedAt.toIso8601String(),
    });
  }

  /// JSON文字列からReviewモデルに変換
  Review _reviewFromJson(String jsonStr) {
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    return Review(
      id: map['id'] as String,
      bookId: map['bookId'] as String,
      rating: map['rating'] as int,
      text: map['text'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async {
    return _box.values
        .map(_reviewFromJson)
        .where((review) => review.bookId == bookId)
        .toList();
  }

  @override
  Future<void> addReview(Review review) async {
    await _box.put(review.id, _reviewToJson(review));
  }

  @override
  Future<void> updateReview(Review review) async {
    await _box.put(review.id, _reviewToJson(review));
  }

  @override
  Future<void> deleteReview(String id) async {
    await _box.delete(id);
  }
}
