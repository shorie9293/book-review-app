import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/features/locations/domain/shelf_location_service.dart';

Book _book(String id, {String? location}) {
  return Book(
    id: id,
    title: '本$id',
    author: '著者',
    isbn: 'isbn-$id',
    location: location,
  );
}

void main() {
  group('ShelfLocationService.normalize', () {
    test('全角英数字を半角に変換する', () {
      expect(ShelfLocationService.normalize('ＡＢＣ１２３'), 'ABC123');
      expect(ShelfLocationService.normalize('ａｂｃ'), 'abc');
    });

    test('全角スペースを半角にし、連続空白を1つに圧縮してtrimする', () {
      expect(ShelfLocationService.normalize('　本棚　 一段目　'), '本棚 一段目');
      expect(ShelfLocationService.normalize('  本棚   二段目  '), '本棚 二段目');
    });

    test('全角英数字と空白の混在を正規化する', () {
      expect(ShelfLocationService.normalize('　本棚Ａ　 　一段目　'), '本棚A 一段目');
    });

    test('空文字・空白のみは空文字になる', () {
      expect(ShelfLocationService.normalize(''), '');
      expect(ShelfLocationService.normalize('   '), '');
      expect(ShelfLocationService.normalize('　　'), '');
    });
  });

  group('isSet / locationOf', () {
    test('locationがnullの本は未設定', () {
      final book = _book('1');
      expect(ShelfLocationService.isSet(book), isFalse);
      expect(ShelfLocationService.locationOf(book), isNull);
    });

    test('locationが空白のみの本は未設定', () {
      final book = _book('1', location: '　 ');
      expect(ShelfLocationService.isSet(book), isFalse);
      expect(ShelfLocationService.locationOf(book), isNull);
    });

    test('設定済みの本は正規化済み文字列を返す', () {
      final book = _book('1', location: '　本棚Ａ　一段目　');
      expect(ShelfLocationService.isSet(book), isTrue);
      expect(ShelfLocationService.locationOf(book), '本棚A 一段目');
    });
  });

  group('availableLocations', () {
    test('件数降順→名前昇順で返す', () {
      final books = [
        _book('1', location: '書斎'),
        _book('2', location: '居間'),
        _book('3', location: '居間'),
        _book('4', location: 'あ棚'),
        _book('5', location: 'い棚'),
      ];
      // 居間=2件、あ棚/い棚/書斎=1件 → 件数同数は名前昇順
      expect(ShelfLocationService.availableLocations(books),
          ['居間', 'あ棚', 'い棚', '書斎']);
    });

    test('空リストは空を返す', () {
      expect(ShelfLocationService.availableLocations(const []), isEmpty);
    });

    test('未設定の本は除外する', () {
      final books = [
        _book('1'),
        _book('2', location: '  '),
        _book('3', location: '本棚'),
      ];
      expect(ShelfLocationService.availableLocations(books), ['本棚']);
    });

    test('正規化後に同一になる所在は統合する', () {
      final books = [
        _book('1', location: '本棚Ａ'),
        _book('2', location: '　本棚Ａ　'),
        _book('3', location: '本棚A'),
      ];
      expect(ShelfLocationService.availableLocations(books), ['本棚A']);
      expect(ShelfLocationService.countByLocation(books)['本棚A'], 3);
    });
  });

  group('countByLocation', () {
    test('正規化所在ごとの冊数を返し、未設定は含めない', () {
      final books = [
        _book('1', location: '本棚'),
        _book('2', location: '　本棚　'),
        _book('3', location: '書斎'),
        _book('4'),
      ];
      final counts = ShelfLocationService.countByLocation(books);
      expect(counts, {'本棚': 2, '書斎': 1});
      expect(counts.containsKey(''), isFalse);
    });

    test('空リストは空マップ', () {
      expect(ShelfLocationService.countByLocation(const []), isEmpty);
    });
  });

  group('matches', () {
    test('locationsが空集合なら全通過', () {
      expect(ShelfLocationService.matches(_book('1', location: '本棚'), const {}),
          isTrue);
      expect(ShelfLocationService.matches(_book('2'), const {}), isTrue);
    });

    test('未設定の本は不一致', () {
      expect(ShelfLocationService.matches(_book('1'), {'本棚'}), isFalse);
    });

    test('複数指定はOR条件で判定する', () {
      final a = _book('1', location: '本棚');
      final b = _book('2', location: '書斎');
      final c = _book('3', location: '押入れ');
      expect(ShelfLocationService.matches(a, {'本棚', '書斎'}), isTrue);
      expect(ShelfLocationService.matches(b, {'本棚', '書斎'}), isTrue);
      expect(ShelfLocationService.matches(c, {'本棚', '書斎'}), isFalse);
    });

    test('指定側・本側の双方を正規化して比較する', () {
      final book = _book('1', location: '　本棚Ａ　');
      expect(ShelfLocationService.matches(book, {'本棚A'}), isTrue);
      expect(
          ShelfLocationService.matches(_book('2', location: '本棚A'), {'　本棚Ａ　'}),
          isTrue);
    });
  });

  group('filterByLocations', () {
    test('条件に合う本だけを新しいリストで返し、入力を破壊しない', () {
      final books = [
        _book('1', location: '本棚'),
        _book('2', location: '書斎'),
        _book('3'),
      ];
      final filtered = ShelfLocationService.filterByLocations(books, {'本棚'});
      expect(filtered.map((b) => b.id).toList(), ['1']);
      expect(books, hasLength(3));
      expect(books.map((b) => b.id).toList(), ['1', '2', '3']);
      expect(identical(filtered, books), isFalse);
    });

    test('空集合はすべて通す', () {
      final books = [_book('1', location: '本棚'), _book('2')];
      expect(ShelfLocationService.filterByLocations(books, const {}),
          hasLength(2));
    });
  });

  group('unlocatedBooks', () {
    test('所在未設定の本だけを返す', () {
      final books = [
        _book('1', location: '本棚'),
        _book('2'),
        _book('3', location: '  '),
      ];
      expect(
        ShelfLocationService.unlocatedBooks(books).map((b) => b.id).toList(),
        ['2', '3'],
      );
    });
  });

  group('suggestions', () {
    test('availableLocationsと同じ結果を返す', () {
      final books = [
        _book('1', location: '本棚'),
        _book('2', location: '本棚'),
        _book('3', location: '書斎'),
      ];
      expect(
        ShelfLocationService.suggestions(books),
        ShelfLocationService.availableLocations(books),
      );
    });
  });

  group('validateNew', () {
    test('空・空白のみはエラー', () {
      expect(ShelfLocationService.validateNew(''), '所在を入力してください');
      expect(ShelfLocationService.validateNew('   '), '所在を入力してください');
      expect(ShelfLocationService.validateNew('　　'), '所在を入力してください');
    });

    test('40文字はOK', () {
      expect(ShelfLocationService.validateNew('あ' * 40), isNull);
    });

    test('41文字はエラー', () {
      expect(ShelfLocationService.validateNew('あ' * 41), '所在は40文字以内で入力してください');
    });

    test('全角英数字も1文字として数える', () {
      expect(ShelfLocationService.validateNew('Ａ' * 40), isNull);
      expect(ShelfLocationService.validateNew('Ａ' * 41), '所在は40文字以内で入力してください');
    });

    test('通常入力はnull', () {
      expect(ShelfLocationService.validateNew('  本棚 一段目  '), isNull);
    });
  });
}
