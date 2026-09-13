import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/features/import/domain/bulk_import_parser.dart';

void main() {
  group('BulkImportParser.parseIsbnList', () {
    test('1行1冊のISBNリストを解析する', () {
      final result = BulkImportParser.parseIsbnList(
        '9784774189079\n9784123456784\n',
      );
      expect(result.entries.length, 2);
      expect(result.validCount, 2);
      expect(result.entries[0].isbn, '9784774189079');
      expect(result.entries[0].line, 1);
      expect(result.entries[1].line, 2);
    });

    test('空行・前後空白を無視する', () {
      final result = BulkImportParser.parseIsbnList(
        '\n  9784774189079  \n\n\n9784123456784\n  \n',
      );
      expect(result.validCount, 2);
      expect(result.entries[0].line, 2);
      expect(result.entries[1].line, 5);
    });

    test('カンマ・タブ・スペース区切りで複数ISBNを許容する', () {
      final result = BulkImportParser.parseIsbnList(
        '9784774189079, 9784123456784\t4123456782',
      );
      expect(result.validCount, 3);
    });

    test('ハイフン付きISBNを正規化する', () {
      final result = BulkImportParser.parseIsbnList('978-4-7741-8907-9');
      expect(result.entries.single.isbn, '9784774189079');
      expect(result.entries.single.status, ImportEntryStatus.valid);
    });

    test('不正なISBNをinvalidとして残す', () {
      final result = BulkImportParser.parseIsbnList('9784774189078\nnot-an-isbn');
      expect(result.validCount, 0);
      expect(result.invalidCount, 2);
    });

    test('入力内の重複は最初の1件のみvalidとする', () {
      final result = BulkImportParser.parseIsbnList(
        '9784774189079\n978-4-7741-8907-9\n9784123456784',
      );
      expect(result.validCount, 2);
      expect(result.duplicateCount, 1);
      expect(result.entries[1].status, ImportEntryStatus.duplicate);
    });

    test('空文字は空の解析結果を返す', () {
      final result = BulkImportParser.parseIsbnList('   \n\n');
      expect(result.isEmpty, isTrue);
      expect(result.hasImportable, isFalse);
    });
  });

  group('BulkImportParser.parseCsv', () {
    test('ヘッダ行からisbn列を解決する', () {
      final result = BulkImportParser.parseCsv(
        'isbn,title,author\n9784774189079,吾輩は猫である,夏目漱石\n',
      );
      expect(result.validCount, 1);
      expect(result.entries.single.isbn, '9784774189079');
      expect(result.entries.single.title, '吾輩は猫である');
      expect(result.entries.single.author, '夏目漱石');
      expect(result.entries.single.line, 2);
    });

    test('日本語ヘッダ（書名/著者）を解決する', () {
      final result = BulkImportParser.parseCsv(
        'ISBN,書名,著者\n9784123456784,坊っちゃん,夏目漱石\n',
      );
      expect(result.entries.single.title, '坊っちゃん');
      expect(result.entries.single.author, '夏目漱石');
    });

    test('ヘッダ無しは ISBN,書名,著者 の並びとして解釈する', () {
      final result = BulkImportParser.parseCsv('9784774189079,吾輩は猫である,夏目漱石\n');
      expect(result.validCount, 1);
      expect(result.entries.single.isbn, '9784774189079');
      expect(result.entries.single.title, '吾輩は猫である');
    });

    test('ダブルクォート囲みとエスケープを扱う', () {
      final result = BulkImportParser.parseCsv(
        'isbn,title,author\n9784123456784,"タイトル, カンマ入り","著者 ""引用"" 付き"\n',
      );
      expect(result.entries.single.title, 'タイトル, カンマ入り');
      expect(result.entries.single.author, '著者 "引用" 付き');
    });

    test('ISBNだけで書名・著者が空でも取り込める', () {
      final result = BulkImportParser.parseCsv('isbn\n9784774189079\n');
      expect(result.validCount, 1);
      expect(result.entries.single.title, isNull);
      expect(result.entries.single.author, isNull);
    });

    test('CSV内の重複とISBN不正を判定する', () {
      final result = BulkImportParser.parseCsv(
        'isbn,title\n9784774189079,A\n9784774189079,B\n12345,C\n',
      );
      expect(result.validCount, 1);
      expect(result.duplicateCount, 1);
      expect(result.invalidCount, 1);
    });

    test('CRLFと末尾空行を処理する', () {
      final result = BulkImportParser.parseCsv(
        'isbn,title\r\n9784774189079,A\r\n\r\n',
      );
      expect(result.validCount, 1);
    });
  });
}
