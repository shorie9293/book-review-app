import 'dart:convert';

/// 本棚の検索語履歴（新しい順・最大 [maxEntries] 件）。
///
/// 値オブジェクトとして振る舞い、[add] は常に新しいインスタンスを返す。
/// 永続化形式は [encode]/[SearchHistory.decode] が担い、
/// 破損データでも例外を投げず空の履歴へ倒す。
class SearchHistory {
  /// 保持する履歴の上限件数。
  static const int maxEntries = 8;

  final List<String> _entries;

  /// [entries] は新しい順で与える。空文字・重複・上限超過は正規化して落とす。
  SearchHistory([List<String>? entries])
      : _entries = _normalizeAll(entries ?? const <String>[]);

  /// 新しい順の履歴（変更不可）。
  List<String> get entries => List<String>.unmodifiable(_entries);

  /// 履歴が空か。
  bool get isEmpty => _entries.isEmpty;

  /// 履歴が空でないか。
  bool get isNotEmpty => _entries.isNotEmpty;

  /// 保持件数。
  int get length => _entries.length;

  /// 検索語を履歴の先頭へ追加した新しい履歴を返す。
  ///
  /// - 前後の空白（全角空白含む）を除去する
  /// - 全角空白は半角空白へ、連続空白は 1 個へ畳む
  /// - 正規化後に空なら元の履歴をそのまま返す（変更なし）
  /// - 大文字小文字を無視して一致する既存項目は取り除き、先頭へ表記を更新して積む
  /// - [maxEntries] を超えた古い項目は捨てる
  SearchHistory add(String raw) {
    final value = normalize(raw);
    if (value.isEmpty) return this;

    final lowered = value.toLowerCase();
    final next = <String>[
      value,
      for (final entry in _entries)
        if (entry.toLowerCase() != lowered) entry,
    ];
    return SearchHistory(next.take(maxEntries).toList());
  }

  /// 履歴を JSON 文字列へ変換する。
  String encode() => jsonEncode(_entries);

  /// [encoded] から履歴を復元する。破損・null・型不一致は空の履歴を返す。
  factory SearchHistory.decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return SearchHistory();
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return SearchHistory();
      final values = <String>[];
      for (final item in decoded) {
        if (item is String) values.add(item);
      }
      return SearchHistory(values);
    } catch (_) {
      return SearchHistory();
    }
  }

  /// 検索語を正規化する（trim・全角空白→半角・連続空白畳み）。
  static String normalize(String raw) {
    final replaced = raw.replaceAll('\u3000', ' ');
    final collapsed = replaced.replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.trim();
  }

  static List<String> _normalizeAll(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in values) {
      final value = normalize(raw);
      if (value.isEmpty) continue;
      if (!seen.add(value.toLowerCase())) continue;
      result.add(value);
      if (result.length >= maxEntries) break;
    }
    return result;
  }

  @override
  String toString() => 'SearchHistory($_entries)';
}
