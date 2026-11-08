import 'package:book_review_app/core/search/search_history.dart';
import 'package:book_review_app/core/search/search_history_store.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/bookshelf/domain/library_query.dart';
import 'package:book_review_app/features/bookshelf/presentation/library_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 記録だけを行う試練用の履歴ストア。
class _FakeSearchHistoryStore implements SearchHistoryStore {
  _FakeSearchHistoryStore([SearchHistory? initial])
      : _stored = initial ?? SearchHistory();

  SearchHistory _stored;
  int saveCount = 0;

  List<String> get entries => _stored.entries;

  @override
  Future<SearchHistory> load() async => _stored;

  @override
  Future<void> save(SearchHistory history) async {
    _stored = history;
    saveCount++;
  }
}

/// 常に失敗する履歴ストア（永続化基盤が無い環境の再現）。
class _ThrowingSearchHistoryStore implements SearchHistoryStore {
  @override
  Future<SearchHistory> load() async => throw StateError('no storage');

  @override
  Future<void> save(SearchHistory history) async =>
      throw StateError('no storage');
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<void> _pumpBar(
  WidgetTester tester, {
  required SearchHistoryStore store,
  LibraryQuery query = const LibraryQuery(),
  ValueChanged<LibraryQuery>? onChanged,
}) async {
  await tester.pumpWidget(_wrap(LibraryFilterBar(
    query: query,
    totalCount: 10,
    filteredCount: 7,
    onChanged: onChanged ?? (_) {},
    searchHistoryStore: store,
  )));
  await tester.pump();
}

void main() {
  testWidgets('履歴が無いときはチップを表示しない', (tester) async {
    final store = _FakeSearchHistoryStore();
    await _pumpBar(tester, store: store);

    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('保存済みの履歴を起動時に読み出してチップ表示する', (tester) async {
    final store = _FakeSearchHistoryStore(
      SearchHistory().add('夏目漱石').add('吾輩は猫である'),
    );
    await _pumpBar(tester, store: store);

    expect(find.byKey(AppKeys.librarySearchHistoryChip('吾輩は猫である')),
        findsOneWidget);
    expect(
        find.byKey(AppKeys.librarySearchHistoryChip('夏目漱石')), findsOneWidget);
  });

  testWidgets('検索確定（onSubmitted）で履歴が保存される', (tester) async {
    final store = _FakeSearchHistoryStore();
    await _pumpBar(tester, store: store);

    await tester.enterText(find.byKey(const Key('library_search_field')), '草枕');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(store.saveCount, 1);
    expect(store.entries, ['草枕']);
    expect(find.byKey(AppKeys.librarySearchHistoryChip('草枕')), findsOneWidget);
  });

  testWidgets('空語で確定しても履歴を保存しない', (tester) async {
    final store = _FakeSearchHistoryStore();
    await _pumpBar(tester, store: store);

    await tester.enterText(
        find.byKey(const Key('library_search_field')), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(store.saveCount, 0);
    expect(store.entries, isEmpty);
  });

  testWidgets('履歴チップのタップで入力欄と query が同時に更新される', (tester) async {
    final store = _FakeSearchHistoryStore(SearchHistory().add('坊っちゃん'));
    LibraryQuery? captured;
    await _pumpBar(tester, store: store, onChanged: (q) => captured = q);

    await tester.tap(find.byKey(AppKeys.librarySearchHistoryChip('坊っちゃん')));
    await tester.pump();

    expect(captured?.text, '坊っちゃん');
    final field =
        tester.widget<TextField>(find.byKey(const Key('library_search_field')));
    expect(field.controller?.text, '坊っちゃん');
  });

  testWidgets('画面離脱（dispose）時に現在の検索語を保存する', (tester) async {
    final store = _FakeSearchHistoryStore();
    await _pumpBar(tester, store: store);

    await tester.enterText(
        find.byKey(const Key('library_search_field')), '三四郎');
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(store.saveCount, 1);
    expect(store.entries, ['三四郎']);
  });

  testWidgets('検索語が空のまま離脱したときは保存しない', (tester) async {
    final store = _FakeSearchHistoryStore();
    await _pumpBar(tester, store: store);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(store.saveCount, 0);
  });

  testWidgets('ストアが例外を投げても検索・絞込は動作する', (tester) async {
    final store = _ThrowingSearchHistoryStore();
    LibraryQuery? captured;
    await _pumpBar(tester, store: store, onChanged: (q) => captured = q);

    await tester.enterText(find.byKey(const Key('library_search_field')), '吾輩');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(captured?.text, '吾輩');
    expect(tester.takeException(), isNull);
  });
}
