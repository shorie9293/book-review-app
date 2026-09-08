import 'package:book_review_app/domain/models/review.dart';

/// 年間読書チャレンジの純粋ロジック。
///
/// 入力（全レビュー集合・目標冊数・基準日時）から
/// 年間読了冊数・進捗率・達成状態を副作用なく算出する。
/// 永続化・UI には依存しないため単体試練が容易。
class ReadingChallengeService {
  ReadingChallengeService._();

  /// 指定年のうちに読了（レビュー作成）した書籍の冊数を返す。
  ///
  /// 「読了 = その書籍にレビューが存在する」とみなし、
  /// 同一書籍の複数レビューは 1 冊として数える（distinct bookId）。
  static int booksReadInYear(List<Review> reviews, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final bookIds = <String>{};
    for (final review in reviews) {
      if (review.createdAt.year == ref.year) {
        bookIds.add(review.bookId);
      }
    }
    return bookIds.length;
  }

  /// 進捗率（0.0〜1.0 にクランプ）を返す。目標が 0 以下の場合は 0.0。
  static double progress(int read, int target) {
    if (target <= 0) return 0.0;
    return (read / target).clamp(0.0, 1.0);
  }

  /// 目標冊数を達成したか。目標未設定（0 以下）では達成とはみなさない。
  static bool isAchieved(int read, int target) {
    return target > 0 && read >= target;
  }
}
