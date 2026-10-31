import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/state/load_state.dart';

void main() {
  group('LoadState', () {
    test('4つの局面をファクトリで作り、getter が一致する', () {
      final loading = LoadState<int>.loading();
      final data = LoadState<int>.data(3);
      final empty = LoadState<int>.empty();
      final error = LoadState<int>.error('失敗');

      expect(loading.isLoading, isTrue);
      expect(loading.phase, LoadPhase.loading);
      expect(loading.value, isNull);

      expect(data.isData, isTrue);
      expect(data.phase, LoadPhase.data);
      expect(data.value, 3);

      expect(empty.isEmpty, isTrue);
      expect(empty.phase, LoadPhase.empty);
      expect(empty.value, isNull);

      expect(error.isError, isTrue);
      expect(error.phase, LoadPhase.error);
      expect(error.message, '失敗');
      expect(error.retryable, isTrue);

      // 局面は排他（1つだけ true）
      for (final state in [loading, data, empty, error]) {
        final flags = [state.isLoading, state.isData, state.isEmpty, state.isError];
        expect(flags.where((f) => f).length, 1);
      }
    });

    test('error は retryable と cause を保持する', () {
      final cause = StateError('disk');
      final state = LoadState<int>.error(
        '読めません',
        retryable: false,
        cause: cause,
      );
      expect(state.message, '読めません');
      expect(state.retryable, isFalse);
      expect(state.cause, same(cause));
    });

    test('when が局面ごとのコールバックへ委譲する', () {
      String describe(LoadState<int> s) => s.when(
            loading: () => 'loading',
            data: (v) => 'data:$v',
            empty: () => 'empty',
            error: (m, r) => 'error:$m:$r',
          );

      expect(describe(LoadState<int>.loading()), 'loading');
      expect(describe(LoadState<int>.data(7)), 'data:7');
      expect(describe(LoadState<int>.empty()), 'empty');
      expect(
        describe(LoadState<int>.error('x', retryable: false)),
        'error:x:false',
      );
    });

    test('等価性・hashCode は値で決まり、cause は含めない', () {
      expect(LoadState<int>.loading(), LoadState<int>.loading());
      expect(LoadState<int>.data(1), LoadState<int>.data(1));
      expect(LoadState<int>.empty(), LoadState<int>.empty());
      expect(LoadState<int>.error('e'), LoadState<int>.error('e'));
      expect(
        LoadState<int>.error('e').hashCode,
        LoadState<int>.error('e').hashCode,
      );

      expect(LoadState<int>.data(1), isNot(LoadState<int>.data(2)));
      expect(LoadState<int>.empty(), isNot(LoadState<int>.error('e')));
      expect(
        LoadState<int>.error('e', retryable: false),
        isNot(LoadState<int>.error('e')),
      );
      // cause が違っても等価
      expect(
        LoadState<int>.error('e', cause: Exception('a')),
        LoadState<int>.error('e', cause: Exception('b')),
      );
    });

    test('toString に局面が現れる', () {
      expect(LoadState<int>.loading().toString(), contains('loading'));
      expect(LoadState<int>.data(5).toString(), contains('5'));
      expect(LoadState<int>.empty().toString(), contains('empty'));
      expect(
        LoadState<int>.error('壊れた').toString(),
        contains('壊れた'),
      );
    });

    test('不正引数は ArgumentError', () {
      expect(() => LoadState<Object?>.data(null), throwsArgumentError);
      expect(() => LoadState<String>.error(''), throwsArgumentError);
      expect(() => LoadState<String>.error('   '), throwsArgumentError);
    });
  });

  group('LoadResult', () {
    test('success / failure の getter が一致する', () {
      final ok = LoadResult<int>.success(9);
      final ng = LoadResult<int>.failure('だめ');

      expect(ok.isSuccess, isTrue);
      expect(ok.isFailure, isFalse);
      expect(ok.valueOrNull, 9);
      expect(ok.message, isNull);

      expect(ng.isFailure, isTrue);
      expect(ng.isSuccess, isFalse);
      expect(ng.valueOrNull, isNull);
      expect(ng.message, 'だめ');
      expect(ng.retryable, isTrue);
    });

    test('failure は retryable と cause を保持する', () {
      final cause = ArgumentError('bad');
      final ng = LoadResult<int>.failure(
        '復元不能',
        retryable: false,
        cause: cause,
      );
      expect(ng.retryable, isFalse);
      expect(ng.cause, same(cause));
    });

    test('when が成功・失敗で分岐する', () {
      String describe(LoadResult<int> r) => r.when(
            success: (v) => 'ok:$v',
            failure: (m, retryable) => 'ng:$m:$retryable',
          );

      expect(describe(LoadResult<int>.success(2)), 'ok:2');
      expect(
        describe(LoadResult<int>.failure('x', retryable: false)),
        'ng:x:false',
      );
    });

    test('等価性・hashCode は 値・message・retryable で決まる', () {
      expect(LoadResult<int>.success(1), LoadResult<int>.success(1));
      expect(LoadResult<int>.failure('e'), LoadResult<int>.failure('e'));
      expect(
        LoadResult<int>.failure('e').hashCode,
        LoadResult<int>.failure('e').hashCode,
      );
      expect(LoadResult<int>.success(1), isNot(LoadResult<int>.success(2)));
      expect(LoadResult<int>.success(1), isNot(LoadResult<int>.failure('1')));
      expect(
        LoadResult<int>.failure('e', retryable: false),
        isNot(LoadResult<int>.failure('e')),
      );
      expect(
        LoadResult<int>.failure('e', cause: Exception('a')),
        LoadResult<int>.failure('e', cause: Exception('b')),
      );
    });

    test('toString に状態が現れる', () {
      expect(LoadResult<int>.success(4).toString(), contains('success'));
      expect(LoadResult<int>.failure('壊れ').toString(), contains('壊れ'));
    });

    test('不正引数は ArgumentError', () {
      expect(
        () => LoadResult<Object?>.success(null),
        throwsArgumentError,
      );
      expect(() => LoadResult<int>.failure(''), throwsArgumentError);
      expect(() => LoadResult<int>.failure('  '), throwsArgumentError);
    });
  });
}
