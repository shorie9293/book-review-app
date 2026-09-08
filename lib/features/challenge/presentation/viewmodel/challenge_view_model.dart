import 'package:flutter/foundation.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/challenge/domain/reading_challenge_service.dart';

/// 年間読書チャレンジ画面の状態を管理する ViewModel。
///
/// 目標冊数の読み書きと、年間読了冊数・進捗・達成状態の算出を担う。
class ChallengeViewModel extends ChangeNotifier {
  int _target = 0;
  int _read = 0;
  bool _achieved = false;
  bool _isLoading = true;

  /// 年間目標冊数（未設定なら 0）
  int get target => _target;

  /// 今年読了した書籍数
  int get read => _read;

  /// 目標達成済みか
  bool get isAchieved => _achieved;

  /// 読み込み中か
  bool get isLoading => _isLoading;

  /// 進捗率（0.0〜1.0）。目標未設定時は 0.0。
  double get progress =>
      ReadingChallengeService.progress(_read, _target);

  /// リポジトリから目標・全レビューを読み込み進捗を算出する。
  Future<void> load(ChallengeRepository repository) async {
    _isLoading = true;
    notifyListeners();
    try {
      final reviews = await repository.getAllReviews();
      final target = await repository.getAnnualTarget();
      final read =
          ReadingChallengeService.booksReadInYear(reviews);
      _read = read;
      _target = target;
      _achieved = ReadingChallengeService.isAchieved(read, target);
      _isLoading = false;
    } catch (_) {
      _isLoading = false;
    }
    notifyListeners();
  }

  /// 年間目標冊数を設定し、進捗を再計算する。
  Future<void> setTarget(ChallengeRepository repository, int target) async {
    await repository.setAnnualTarget(target);
    await load(repository);
  }
}
