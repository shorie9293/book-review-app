import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/challenge/presentation/challenge_screen.dart';

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

  Future<void> pumpScreen(WidgetTester tester, ChallengeRepository repo) async {
    await tester.pumpWidget(
      MaterialApp(home: ChallengeScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('タイトルが表示される', (tester) async {
    await pumpScreen(tester, FakeChallengeRepository());
    expect(find.text('年間読書チャレンジ'), findsOneWidget);
  });

  testWidgets('目標未設定時は設定を促す文言を表示する', (tester) async {
    await pumpScreen(tester, FakeChallengeRepository());
    expect(find.text('目標冊数を設定すると進捗を記録できます。'), findsOneWidget);
    expect(find.text('目標を設定する'), findsOneWidget);
  });

  testWidgets('目標・進捗・達成バッジを表示する', (tester) async {
    final repo = FakeChallengeRepository(
      target: 3,
      reviews: [
        reviewInThisYear('r1', 'b1'),
        reviewInThisYear('r2', 'b2'),
        reviewInThisYear('r3', 'b3'),
      ],
    );
    await pumpScreen(tester, repo);

    expect(find.text('3 / 3 冊読了'), findsOneWidget);
    expect(find.textContaining('年間目標達成'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('目標変更ダイアログから目標を設定できる', (tester) async {
    await pumpScreen(tester, FakeChallengeRepository());

    await tester.tap(find.byKey(const Key('challenge_edit_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('challenge_target_field')),
      '12',
    );
    await tester.tap(find.byKey(const Key('challenge_target_save')));
    await tester.pumpAndSettle();

    expect(find.text('0 / 12 冊読了'), findsOneWidget);
    expect(find.text('目標を変更する'), findsOneWidget);
  });
}
