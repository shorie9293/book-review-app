import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 配線テスト: 本棚 AppBar に「アプリについて」導線が存在すること。
void main() {
  test('bookshelf_screen: about_entry 導線と AboutScreen 遷移が存在する', () {
    final source =
        File('lib/features/bookshelf/presentation/bookshelf_screen.dart')
            .readAsStringSync();
    expect(source.contains("Key('about_entry')"), isTrue);
    expect(source.contains('AboutScreen('), isTrue);
  });

  test('about_app_keys.dart が既存 AppKeys とは別ファイルで一元管理されている', () {
    final keysSource = File(
      'lib/features/about/presentation/about_app_keys.dart',
    ).readAsStringSync();
    for (final key in [
      'about_screen',
      'about_entry',
      'about_license_button',
      'about_privacy_button',
      'about_contact_button',
      'about_copy_button',
    ]) {
      expect(keysSource.contains(key), isTrue, reason: key);
    }
  });
}
