import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/challenge/data/hive_challenge_repository.dart';
import 'package:hive/hive.dart';

/// Hive の `reviews` ボックスから全レビューを読み出す（孤児検出用）。
///
/// バックアップの collect は現存する本のレビューしか集めないため、
/// 保存先を失ったレビューを検出するには全件読みが必要になる。
///
/// 読み出しに失敗してもバックアップ画面を壊さないよう、例外は投げずに
/// 空リストを返す（沈黙フォールバック）。Hive 未初期化・ボックス未開放の
/// 環境（試練・起動直後）では**開かずに**空を返す — ここで `openBox` を
/// 呼ぶと headless ではゾーンへ HiveError が漏れて既存試練が赤化する。
Future<List<Review>> loadAllReviewsFromHive() async {
  try {
    if (!Hive.isBoxOpen(HiveChallengeRepository.reviewsBoxName)) {
      return const <Review>[];
    }
    final repository = HiveChallengeRepository();
    await repository.init();
    return await repository.getAllReviews();
  } catch (_) {
    return const <Review>[];
  }
}
