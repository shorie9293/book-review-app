import 'package:book_review_app/domain/models/book.dart';

/// 同一ISBNで重複した蔵書の組。
///
/// [books] は2冊以上で、追加日時の昇順（null は末尾）に整列済みであることを
/// 前提とする。先頭が統合時の代表蔵書となる。
class DuplicateBookGroup {
  /// 正規化済みISBN（空でない）。
  final String isbnKey;

  /// 組に属する蔵書。2冊以上・追加日時昇順。
  final List<Book> books;

  const DuplicateBookGroup({required this.isbnKey, required this.books});

  /// 組に含まれる蔵書数。
  int get count => books.length;

  /// 統合時の代表蔵書（最も古く追加された1冊）。
  Book get representative => books.first;

  /// 組に含まれる蔵書の id 一覧（組の順序を保つ）。
  List<String> get bookIds => books.map((b) => b.id).toList();

  /// 画面表示用の冊数ラベル（例: '3冊'）。
  String get countLabel => '$count冊';

  @override
  String toString() => 'DuplicateBookGroup(isbnKey: $isbnKey, count: $count)';
}
