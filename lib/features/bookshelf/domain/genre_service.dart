import 'package:book_review_app/domain/models/book.dart';

/// ジャンルに関する純粋なドメイン処理を提供するサービス。
///
/// 正規化・検証・集計・絞り込みなど状態を持たない関数のみを扱う。
class GenreService {
  const GenreService._();

  /// ジャンル名の最大文字数（正規化後の長さで判定する）。
  static const int maxGenreLength = 20;

  /// 正規化: 全角英数字・全角スペース → 半角、小文字化、空白圧縮、trim。
  static String normalize(String raw) {
    final sb = StringBuffer();
    for (final ch in raw.runes) {
      if (ch >= 0xFF01 && ch <= 0xFF5E) {
        // 全角ASCII → 半角ASCII
        sb.writeCharCode(ch - 0xFEE0);
      } else if (ch == 0x3000) {
        // 全角スペース → 半角スペース
        sb.writeCharCode(0x20);
      } else {
        sb.writeCharCode(ch);
      }
    }
    final halfWidth = sb.toString();
    final lower = halfWidth.toLowerCase();
    return lower.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 各要素を正規化し、空を除外・正規化後の重複を除去したリストを返す（順序保持）。
  static List<String> canonicalList(List<String> raw) {
    final result = <String>[];
    final seen = <String>{};
    for (final element in raw) {
      final normalized = normalize(element);
      if (normalized.isEmpty || !seen.add(normalized)) continue;
      result.add(normalized);
    }
    return result;
  }

  /// 新規ジャンル [candidate] を [existing] に追加できるか検証する。
  ///
  /// 正常なら null、問題があれば日本語のエラーメッセージを返す。
  static String? validateNew(List<String> existing, String candidate) {
    final normalized = normalize(candidate);
    if (normalized.isEmpty) {
      return 'ジャンル名を入力してください';
    }
    final duplicateExisting = existing.any((e) => normalize(e) == normalized);
    if (duplicateExisting) {
      return '「$normalized」は既に登録されています';
    }
    if (normalized.length > maxGenreLength) {
      return 'ジャンル名は$maxGenreLength文字以内で入力してください';
    }
    return null;
  }

  /// [books] のジャンルを正規化した上で件数集計する。
  static Map<String, int> countByGenre(List<Book> books) {
    final counts = <String, int>{};
    for (final book in books) {
      for (final genre in canonicalList(book.genres)) {
        counts[genre] = (counts[genre] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// 正規化済みジャンル名を「件数降順 → 同数は名前昇順」で返す。
  static List<String> availableGenres(List<Book> books) {
    final counts = countByGenre(books);
    final genres = counts.keys.toList();
    genres.sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      if (byCount != 0) return byCount;
      return a.compareTo(b);
    });
    return genres;
  }

  /// [book] が [selected] のジャンル条件に合致するかどうか（OR条件）。
  ///
  /// selected が空なら全件通過（true）。比較は双方正規化して行う。
  static bool matches(Book book, Set<String> selected) {
    if (selected.isEmpty) return true;
    final normalizedSelected =
        selected.map(normalize).where((s) => s.isNotEmpty).toSet();
    if (normalizedSelected.isEmpty) return true;
    final bookGenres = canonicalList(book.genres).toSet();
    return bookGenres.intersection(normalizedSelected).isNotEmpty;
  }
}
