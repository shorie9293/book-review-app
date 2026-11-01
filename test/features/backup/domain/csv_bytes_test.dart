import 'dart:convert';

import 'package:book_review_app/features/backup/domain/backup_service.dart';
import 'package:book_review_app/features/backup/domain/csv_bytes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('csvBytes', () {
    test('先頭3バイトが UTF-8 BOM (EF BB BF) になる', () {
      final bytes = csvBytes('書名,著者');

      expect(bytes.length, greaterThan(3));
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    });

    test('BOM を除いた本体は utf8 で元の文字列へ戻る', () {
      const csv = '書名,著者\n吾輩は猫である,夏目漱石';
      final bytes = csvBytes(csv);

      expect(utf8.decode(bytes.sublist(3)), csv);
    });

    test('withUtf8Bom は U+FEFF を前置するだけ', () {
      expect(withUtf8Bom('a,b'), '\uFEFFa,b');
    });
  });

  group('BackupService.exportBooksCsv', () {
    test('戻り値に BOM (U+FEFF) を含めない（BOM は共有層で付く契約）', () {
      final csv = BackupService.exportBooksCsv(const []);

      expect(csv.contains('\uFEFF'), isFalse);
      expect(csv.startsWith('id,title,author,isbn'), isTrue);
    });
  });
}
