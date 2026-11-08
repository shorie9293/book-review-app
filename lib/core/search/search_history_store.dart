import 'package:shared_preferences/shared_preferences.dart';

import 'package:book_review_app/core/search/search_history.dart';

/// 検索語履歴の永続化抽象。
///
/// 具現化（SharedPreferences / メモリ）を差し替えられるようにするための境界。
abstract class SearchHistoryStore {
  /// 保存済みの履歴を読み出す。未保存・破損時は空の履歴を返す。
  Future<SearchHistory> load();

  /// 履歴を保存する。
  Future<void> save(SearchHistory history);
}

/// SharedPreferences 実装。キーは [storageKey] 固定。
class SharedPreferencesSearchHistoryStore implements SearchHistoryStore {
  /// 保存キー（形式変更時はバージョンを上げる）。
  static const String storageKey = 'library_search_history_v1';

  const SharedPreferencesSearchHistoryStore();

  @override
  Future<SearchHistory> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SearchHistory.decode(prefs.getString(storageKey));
  }

  @override
  Future<void> save(SearchHistory history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, history.encode());
  }
}
