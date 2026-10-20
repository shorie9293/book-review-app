import 'package:book_review_app/domain/models/book.dart';

/// 蔵書の所在（物理的な置き場所）に関する純粋ロジック。
///
/// 入力を破壊せず、[DateTime.now] などの環境依存値も参照しない。
/// 所在文字列の正規化（全角→半角・空白圧縮・trim）を唯一の入口として扱う。
class ShelfLocationService {
  const ShelfLocationService._();

  /// 全角英数字を半角に、全角スペースを半角スペースに変換し、
  /// 連続する空白を1つに圧縮したうえで前後の空白を除去する。
  static String normalize(String raw) {
    final buffer = StringBuffer();
    for (final codePoint in raw.runes) {
      var code = codePoint;
      if (code >= 0xFF01 && code <= 0xFF5E) {
        code -= 0xFEE0;
      } else if (code == 0x3000) {
        code = 0x20;
      }
      buffer.writeCharCode(code);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 所在が設定されているか（正規化して空でないか）。
  static bool isSet(Book book) => locationOf(book) != null;

  /// 正規化済みの所在。未設定なら null。
  static String? locationOf(Book book) {
    final normalized = normalize(book.location ?? '');
    return normalized.isEmpty ? null : normalized;
  }

  /// 所在ごとの冊数。未設定の本は含めない。
  static Map<String, int> countByLocation(List<Book> books) {
    final counts = <String, int>{};
    for (final book in books) {
      final location = locationOf(book);
      if (location == null) continue;
      counts[location] = (counts[location] ?? 0) + 1;
    }
    return counts;
  }

  /// 設定済み所在の一覧（件数降順→名前昇順）。
  static List<String> availableLocations(List<Book> books) {
    final counts = countByLocation(books);
    if (counts.isEmpty) return const [];
    return counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        if (byCount != 0) return byCount;
        return a.compareTo(b);
      });
  }

  /// 入力補完用の候補（[availableLocations] の別名）。
  static List<String> suggestions(List<Book> books) =>
      availableLocations(books);

  /// [locations] が空なら全通過。それ以外は所在がいずれかに一致するか（OR）。
  /// 所在未設定の本は不一致。
  static bool matches(Book book, Set<String> locations) {
    if (locations.isEmpty) return true;
    final own = locationOf(book);
    if (own == null) return false;
    for (final candidate in locations) {
      if (normalize(candidate) == own) return true;
    }
    return false;
  }

  /// [matches] で絞り込んだ新しいリストを返す（入力は変更しない）。
  static List<Book> filterByLocations(List<Book> books, Set<String> locations) {
    return books.where((book) => matches(book, locations)).toList();
  }

  /// 所在が未設定の本（正規化して空）。
  static List<Book> unlocatedBooks(List<Book> books) {
    return books.where((book) => !isSet(book)).toList();
  }

  /// 新規所在の入力検証。問題なければ null。
  ///
  /// 正規化後の文字数で上限（40文字）を判定する。全角1文字も1文字と数える。
  static String? validateNew(String raw) {
    if (raw.trim().isEmpty) return '所在を入力してください';
    final normalized = normalize(raw);
    if (normalized.isEmpty) return '所在を入力してください';
    if (normalized.runes.length > 40) return '所在は40文字以内で入力してください';
    return null;
  }
}
