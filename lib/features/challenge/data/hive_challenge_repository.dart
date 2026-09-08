import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'dart:convert';

/// Hive を使用した [ChallengeRepository] の実装。
///
/// 年間目標冊数は専用ボックス `challenge` に保存し、
/// 全レビュー一覧はレビュー機能と共有する `reviews` ボックス（`Box<String>`・JSON）から読む。
class HiveChallengeRepository implements ChallengeRepository {
  static const String _targetBoxName = 'challenge';
  static const String _reviewsBoxName = 'reviews';
  static const String _targetKey = 'annual_target';

  late Box _targetBox;
  late Box<String> _reviewsBox;

  /// 初期化（テスト時は明示的に呼び出す）
  Future<void> init({String? boxName}) async {
    _targetBox = await Hive.openBox(boxName ?? _targetBoxName);
    _reviewsBox = await Hive.openBox<String>(_reviewsBoxName);
  }

  /// JSON文字列からReviewモデルに変換（reviews ボックスの共有スキーマ）
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
  Future<int> getAnnualTarget() async {
    final value = _targetBox.get(_targetKey, defaultValue: 0);
    return value is int ? value : 0;
  }

  @override
  Future<void> setAnnualTarget(int target) async {
    await _targetBox.put(_targetKey, target < 0 ? 0 : target);
  }

  @override
  Future<List<Review>> getAllReviews() async {
    return _reviewsBox.values
        .map((raw) => _reviewFromJson(raw))
        .toList();
  }
}
