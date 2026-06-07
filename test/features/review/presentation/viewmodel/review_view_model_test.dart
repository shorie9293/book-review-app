import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/review/presentation/viewmodel/review_view_model.dart';

/// Fake ReviewRepository for testing ViewModel
class FakeReviewRepository implements ReviewRepository {
  final Map<String, List<Review>> _store = {};

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async {
    return List.unmodifiable(_store[bookId] ?? []);
  }

  @override
  Future<void> addReview(Review review) async {
    _store.putIfAbsent(review.bookId, () => []);
    _store[review.bookId]!.add(review);
  }

  @override
  Future<void> updateReview(Review review) async {
    final list = _store[review.bookId];
    if (list != null) {
      final index = list.indexWhere((r) => r.id == review.id);
      if (index != -1) list[index] = review;
    }
  }

  @override
  Future<void> deleteReview(String id) async {
    for (final list in _store.values) {
      list.removeWhere((r) => r.id == id);
    }
  }
}

Review _testReview({
  String id = 'review-1',
  String bookId = 'book-1',
  int rating = 4,
  String text = '良い本でした',
  DateTime? createdAt,
}) {
  return Review(
    id: id,
    bookId: bookId,
    rating: rating,
    text: text,
    createdAt: createdAt ?? DateTime(2024, 1, 15),
  );
}

void main() {
  group('ReviewViewModel', () {
    late ReviewViewModel viewModel;
    late FakeReviewRepository repository;

    setUp(() {
      viewModel = ReviewViewModel();
      repository = FakeReviewRepository();
    });

    tearDown(() {
      viewModel.dispose();
    });

    group('initial state', () {
      test('reviews is empty', () {
        expect(viewModel.reviews, isEmpty);
      });

      test('isLoading is true', () {
        expect(viewModel.isLoading, isTrue);
      });

      test('errorMessage is null', () {
        expect(viewModel.errorMessage, isNull);
      });
    });

    group('loadReviews', () {
      test('loads reviews for given bookId', () async {
        await repository.addReview(_testReview(id: 'r1', bookId: 'b1', text: 'Review 1'));
        await repository.addReview(_testReview(id: 'r2', bookId: 'b1', text: 'Review 2'));
        await repository.addReview(_testReview(id: 'r3', bookId: 'b2', text: 'Other book'));

        await viewModel.loadReviews(repository, 'b1');

        expect(viewModel.reviews.length, 2);
        expect(viewModel.reviews[0].text, 'Review 1');
        expect(viewModel.reviews[1].text, 'Review 2');
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.errorMessage, isNull);
      });

      test('loads empty list when no reviews for bookId', () async {
        await repository.addReview(_testReview(id: 'r1', bookId: 'b1'));

        await viewModel.loadReviews(repository, 'b2');

        expect(viewModel.reviews, isEmpty);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.errorMessage, isNull);
      });

      test('sets errorMessage when repository throws', () async {
        // Use a repository that throws
        final throwingRepo = _ThrowingReviewRepository();
        await viewModel.loadReviews(throwingRepo, 'book-1');

        expect(viewModel.reviews, isEmpty);
        expect(viewModel.errorMessage, isNotNull);
        expect(viewModel.isLoading, isFalse);
      });

      test('notifies listeners on completion', () async {
        var called = false;
        viewModel.addListener(() => called = true);

        await viewModel.loadReviews(repository, 'book-1');

        expect(called, isTrue);
      });

      test('notifies listeners on error', () async {
        final throwingRepo = _ThrowingReviewRepository();

        var called = false;
        viewModel.addListener(() => called = true);

        await viewModel.loadReviews(throwingRepo, 'book-1');

        expect(called, isTrue);
        expect(viewModel.errorMessage, isNotNull);
      });

      test('sets isLoading to true at start and false at end', () async {
        // Use a delayed repository to test intermediate state
        final delayedRepo = _DelayedReviewRepository(
          delay: const Duration(milliseconds: 50),
        );

        final future = viewModel.loadReviews(delayedRepo, 'book-1');

        // isLoading should be true immediately
        expect(viewModel.isLoading, isTrue);

        await future;

        expect(viewModel.isLoading, isFalse);
      });
    });

    group('addReview', () {
      test('adds review and reloads list', () async {
        final review = _testReview(id: 'new', bookId: 'b1', text: 'New review');

        await viewModel.addReview(repository, review);

        // Repository should have it
        final stored = await repository.getReviewsByBookId('b1');
        expect(stored.length, 1);
        expect(stored.first.text, 'New review');

        // ViewModel should reflect it
        expect(viewModel.reviews.length, 1);
        expect(viewModel.reviews.first.text, 'New review');
      });

      test('notifies listeners', () async {
        var called = false;
        viewModel.addListener(() => called = true);

        await viewModel.addReview(repository, _testReview());

        expect(called, isTrue);
      });

      test('handles repository error during add', () async {
        final throwingRepo = _ThrowingReviewRepository();
        final review = _testReview(id: 'fail', text: 'Will fail');

        expect(
          () async => await viewModel.addReview(throwingRepo, review),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('updateReview', () {
      test('updates existing review and reloads', () async {
        await repository.addReview(_testReview(id: 'r1', bookId: 'b1', text: 'Original'));
        await viewModel.loadReviews(repository, 'b1');

        final updated = _testReview(id: 'r1', bookId: 'b1', text: 'Updated');
        await viewModel.updateReview(repository, updated);

        expect(viewModel.reviews.length, 1);
        expect(viewModel.reviews.first.text, 'Updated');

        final stored = await repository.getReviewsByBookId('b1');
        expect(stored.first.text, 'Updated');
      });

      test('notifies listeners', () async {
        await repository.addReview(_testReview(id: 'r1', bookId: 'b1'));
        await viewModel.loadReviews(repository, 'b1');

        var called = false;
        viewModel.addListener(() => called = true);

        await viewModel.updateReview(repository, _testReview(id: 'r1', bookId: 'b1', text: 'Changed'));

        expect(called, isTrue);
      });

      test('handles repository error during update', () async {
        await repository.addReview(_testReview(id: 'r1', bookId: 'b1'));
        await viewModel.loadReviews(repository, 'b1');

        final throwingRepo = _ThrowingReviewRepository();

        expect(
          () async => await viewModel.updateReview(
            throwingRepo,
            _testReview(id: 'r1', text: 'Fail'),
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('deleteReview', () {
      test('deletes review and reloads', () async {
        await repository.addReview(_testReview(id: 'r1', bookId: 'b1', text: 'To delete'));
        await repository.addReview(_testReview(id: 'r2', bookId: 'b1', text: 'To keep'));
        await viewModel.loadReviews(repository, 'b1');

        await viewModel.deleteReview(repository, 'r1');

        expect(viewModel.reviews.length, 1);
        expect(viewModel.reviews.first.text, 'To keep');

        final stored = await repository.getReviewsByBookId('b1');
        expect(stored.length, 1);
      });

      test('notifies listeners', () async {
        await repository.addReview(_testReview(id: 'r-to-del', bookId: 'b1'));
        await viewModel.loadReviews(repository, 'b1');

        var called = false;
        viewModel.addListener(() => called = true);

        await viewModel.deleteReview(repository, 'r-to-del');

        expect(called, isTrue);
      });

      test('handles repository error during delete', () async {
        await repository.addReview(_testReview(id: 'r1', bookId: 'b1'));
        await viewModel.loadReviews(repository, 'b1');

        final throwingRepo = _ThrowingReviewRepository();

        expect(
          () async => await viewModel.deleteReview(throwingRepo, 'r1'),
          throwsA(isA<Exception>()),
        );
      });

      test('throws when deleting non-existent review', () async {
        // The deleteReview method uses firstWhere which will throw
        await expectLater(
          () async => await viewModel.deleteReview(repository, 'non-existent'),
          throwsA(isA<Error>()),
        );
      });
    });
  });
}

/// Repository that always throws, for error-handling tests
class _ThrowingReviewRepository implements ReviewRepository {
  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async {
    throw Exception('Repository error');
  }

  @override
  Future<void> addReview(Review review) async {
    throw Exception('Repository error');
  }

  @override
  Future<void> updateReview(Review review) async {
    throw Exception('Repository error');
  }

  @override
  Future<void> deleteReview(String id) async {
    throw Exception('Repository error');
  }
}

/// Repository with configurable delay, for loading state tests
class _DelayedReviewRepository implements ReviewRepository {
  final Duration delay;

  _DelayedReviewRepository({this.delay = const Duration(milliseconds: 50)});

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async {
    await Future.delayed(delay);
    return [];
  }

  @override
  Future<void> addReview(Review review) async {
    await Future.delayed(delay);
  }

  @override
  Future<void> updateReview(Review review) async {
    await Future.delayed(delay);
  }

  @override
  Future<void> deleteReview(String id) async {
    await Future.delayed(delay);
  }
}
