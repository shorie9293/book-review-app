import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:book_review_app/domain/models/book.dart';

/// OpenBD API を使用してISBNから書籍情報を検索するサービス
class BookSearchService {
  final http.Client client;
  static const String _baseUrl = 'https://api.openbd.jp/v1/get';

  BookSearchService({http.Client? client}) : client = client ?? http.Client();

  /// 指定されたISBNで書籍を検索する
  /// 結果がない場合はnullを返す
  Future<Book?> searchByIsbn(String isbn) async {
    final normalizedIsbn = isbn.replaceAll('-', '');
    final uri = Uri.parse('$_baseUrl?isbn=$normalizedIsbn');

    try {
      final response = await client.get(uri);

      if (response.statusCode != 200) {
        throw Exception('OpenBD API returned status ${response.statusCode}');
      }

      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty || data.first == null) {
        return null;
      }

      final summary = data.first['summary'] as Map<String, dynamic>?;
      if (summary == null) {
        return null;
      }

      return Book(
        id: '', // IDはリポジトリ側で採番
        title: summary['title'] as String? ?? '',
        author: summary['author'] as String? ?? '',
        isbn: isbn,
        coverImageUrl: summary['cover'] as String?,
        publisher: summary['publisher'] as String?,
        publishedDate: summary['pubdate'] as String?,
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to search book: $e');
    }
  }
}
