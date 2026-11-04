import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/input/draft_store.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/review/presentation/review_screen.dart';
import 'package:book_review_app/features/review/presentation/widgets/review_form.dart';

/// メモリ上のレビューリポジトリ。
class _MemoryReviewRepository implements ReviewRepository {
  final Map<String, List<Review>> _store = {};

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async =>
      _store[bookId]?.toList() ?? [];

  @override
  Future<void> addReview(Review review) async {
    _store.putIfAbsent(review.bookId, () => []).add(review);
  }

  @override
  Future<void> updateReview(Review review) async {
    final list = _store[review.bookId];
    if (list == null) return;
    final index = list.indexWhere((r) => r.id == review.id);
    if (index >= 0) list[index] = review;
  }

  @override
  Future<void> deleteReview(String id) async {
    for (final list in _store.values) {
      list.removeWhere((r) => r.id == id);
    }
  }
}

/// 保存が必ず失敗するリポジトリ（下書きを残すことの検証用）。
class _FailingReviewRepository extends _MemoryReviewRepository {
  @override
  Future<void> addReview(Review review) async {
    throw StateError('保存に失敗');
  }
}

Widget _app({
  required ReviewRepository repository,
  DraftStore? draftStore,
}) {
  return MaterialApp(
    home: ReviewScreen(
      bookId: 'book-1',
      reviewRepository: repository,
      draftStore: draftStore,
    ),
  );
}

Future<void> _openAddDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('review_add_fab')));
  await tester.pumpAndSettle();
}

Future<void> _tapOutside(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('未入力なら外側タップで従来どおり閉じる', (tester) async {
    final store = InMemoryDraftStore();
    await tester.pumpWidget(_app(
      repository: _MemoryReviewRepository(),
      draftStore: store,
    ));
    await tester.pumpAndSettle();
    await _openAddDialog(tester);

    await _tapOutside(tester);

    expect(find.byType(ReviewForm), findsNothing);
    expect(find.byKey(const Key('unsaved_changes_dialog')), findsNothing);
  });

  testWidgets('入力後に外側タップすると確認が出て、編集を続けると本文が残る', (tester) async {
    await tester.pumpWidget(_app(
      repository: _MemoryReviewRepository(),
      draftStore: InMemoryDraftStore(),
    ));
    await tester.pumpAndSettle();
    await _openAddDialog(tester);
    await tester.enterText(
      find.byKey(const Key('review_form_text_field')),
      '書きかけのレビュー本文',
    );
    await tester.pumpAndSettle();

    await _tapOutside(tester);

    expect(find.byType(ReviewForm), findsOneWidget);
    expect(find.byKey(const Key('unsaved_changes_dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('unsaved_changes_keep')));
    await tester.pumpAndSettle();

    expect(find.text('書きかけのレビュー本文'), findsOneWidget);
  });

  testWidgets('破棄して閉じても下書きが残り、開き直すと復元される', (tester) async {
    final store = InMemoryDraftStore();
    await tester.pumpWidget(_app(
      repository: _MemoryReviewRepository(),
      draftStore: store,
    ));
    await tester.pumpAndSettle();
    await _openAddDialog(tester);
    await tester.enterText(
      find.byKey(const Key('review_form_text_field')),
      '下書きに残す本文',
    );
    await tester.pumpAndSettle();

    await _tapOutside(tester);
    await tester.tap(find.byKey(const Key('unsaved_changes_discard')));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewForm), findsNothing);

    expect(
      await store.read(ReviewScreen.draftKeyForNew('book-1')),
      contains('下書きに残す本文'),
    );

    await _openAddDialog(tester);
    expect(find.text('下書きに残す本文'), findsOneWidget);
  });

  testWidgets('保存に成功すると下書きが消える', (tester) async {
    final store = InMemoryDraftStore();
    await tester.pumpWidget(_app(
      repository: _MemoryReviewRepository(),
      draftStore: store,
    ));
    await tester.pumpAndSettle();
    await _openAddDialog(tester);
    await tester.tap(find.byKey(const Key('review_form_star_3')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('review_form_text_field')),
      '保存する本文',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('review_form_save_button')));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewForm), findsNothing);
    expect(find.text('保存する本文'), findsOneWidget);
    expect(await store.read(ReviewScreen.draftKeyForNew('book-1')), isNull);
  });

  testWidgets('保存に失敗したら下書きを残す', (tester) async {
    final store = InMemoryDraftStore();
    await tester.pumpWidget(_app(
      repository: _FailingReviewRepository(),
      draftStore: store,
    ));
    await tester.pumpAndSettle();
    await _openAddDialog(tester);
    await tester.tap(find.byKey(const Key('review_form_star_3')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('review_form_text_field')),
      '失敗する保存の本文',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('review_form_save_button')));
    await tester.pumpAndSettle();

    expect(
      await store.read(ReviewScreen.draftKeyForNew('book-1')),
      contains('失敗する保存の本文'),
    );
  });
}
