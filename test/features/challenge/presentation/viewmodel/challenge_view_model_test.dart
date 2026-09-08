import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/challenge/presentation/viewmodel/challenge_view_model.dart';

class FakeChallengeRepository implements ChallengeRepository {
  int _target;
  final List<Review> reviews;
  FakeChallengeRepository({List<Review>? reviews, int target = 0})
      : _target = target,
        reviews = reviews ?? [];

  @override
  Future<int> getAnnualTarget() async => _target;

  @override
  Future<void> setAnnualTarget(int target) async {
    _target = target < 0 ? 0 : target;
  }

  @override
  Future<List<Review>> getAllReviews() async => reviews;
}

void main() {
  final thisYear = DateTime.now().year;

  Review reviewInThisYear(String id, String bookId) {
    return Review(
      id: id,
      bookId: bookId,
      rating: 4,
      text: 'text',
      createdAt: DateTime(thisYear, 1, 15),
    );
  }

  group('ChallengeViewModel', () {
    test('初期状態は目標0・読了0・未達成', () async {
      final vm = ChallengeViewModel();
      expect(vm.target, 0);
      expect(vm.read, 0);
      expect(vm.isAchieved, isFalse);
      expect(vm.isLoading, isTrue);

      await vm.load(FakeChallengeRepository());
      expect(vm.isLoading, isFalse);
      expect(vm.target, 0);
      expect(vm.read, 0);
      expect(vm.isAchieved, isFalse);
      expect(vm.progress, 0.0);
    });

    test('今年の読了冊数と進捗率を算出する', () async {
      final repo = FakeChallengeRepository(
        target: 5,
        reviews: [
          reviewInThisYear('r1', 'b1'),
          reviewInThisYear('r2', 'b2'),
          reviewInThisYear('r3', 'b3'),
        ],
      );
      final vm = ChallengeViewModel();
      await vm.load(repo);

      expect(vm.read, 3);
      expect(vm.target, 5);
      expect(vm.progress, closeTo(0.6, 0.001));
      expect(vm.isAchieved, isFalse);
    });

    test('読了が目標に達すると達成状態になる', () async {
      final reviews = [
        for (var i = 1; i <= 5; i++)
          reviewInThisYear('r$i', 'b$i'),
      ];
      final vm = ChallengeViewModel();
      await vm.load(FakeChallengeRepository(target: 5, reviews: reviews));

      expect(vm.read, 5);
      expect(vm.progress, 1.0);
      expect(vm.isAchieved, isTrue);
    });

    test('setTargetで目標を更新し進捗を再計算する', () async {
      final repo = FakeChallengeRepository(
        reviews: [
          reviewInThisYear('r1', 'b1'),
          reviewInThisYear('r2', 'b2'),
        ],
      );
      final vm = ChallengeViewModel();
      await vm.load(repo);
      expect(vm.target, 0);

      await vm.setTarget(repo, 2);
      expect(vm.target, 2);
      expect(vm.read, 2);
      expect(vm.isAchieved, isTrue);
    });
  });
}
