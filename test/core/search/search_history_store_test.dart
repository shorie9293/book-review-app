import 'package:book_review_app/core/search/search_history.dart';
import 'package:book_review_app/core/search/search_history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = SharedPreferencesSearchHistoryStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('保存キーは library_search_history_v1 で固定されている', () {
    expect(SharedPreferencesSearchHistoryStore.storageKey,
        'library_search_history_v1');
  });

  test('未保存の状態では空の履歴を返す', () async {
    final loaded = await store.load();

    expect(loaded.isEmpty, isTrue);
  });

  test('保存した履歴を同じ順序で読み出せる', () async {
    final history = SearchHistory().add('夏目漱石').add('吾輩は猫である');

    await store.save(history);
    final loaded = await store.load();

    expect(loaded.entries, ['吾輩は猫である', '夏目漱石']);
  });

  test('保存値は固定キーの JSON 文字列として書き込まれる', () async {
    await store.save(SearchHistory().add('草枕'));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(SharedPreferencesSearchHistoryStore.storageKey);

    expect(raw, isNotNull);
    expect(SearchHistory.decode(raw).entries, ['草枕']);
  });

  test('破損した保存値でも例外を投げず空の履歴を返す', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesSearchHistoryStore.storageKey: '{broken',
    });

    final loaded = await store.load();

    expect(loaded.isEmpty, isTrue);
  });

  test('上書き保存すると古い履歴は置き換わる', () async {
    await store.save(SearchHistory().add('古い語'));
    await store.save(SearchHistory().add('新しい語'));

    final loaded = await store.load();

    expect(loaded.entries, ['新しい語']);
  });
}
