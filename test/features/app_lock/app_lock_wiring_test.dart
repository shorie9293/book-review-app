import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 配線テスト: main.dart の home が AppLockGate 経由になっていること、
/// 本棚 AppBar に「アプリロック」導線が存在すること。
void main() {
  test('main.dart: home は AppLockGate(unlockedBuilder: ErrorBoundary)', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source.contains('AppLockGate('), isTrue);
    expect(source.contains('unlockedBuilder: (context) => ErrorBoundary('),
        isTrue);
  });

  test('bookshelf_screen: appLockEntry 導線と設定画面遷移が存在する', () {
    final source =
        File('lib/features/bookshelf/presentation/bookshelf_screen.dart')
            .readAsStringSync();
    expect(source.contains('AppKeys.appLockEntry'), isTrue);
    expect(source.contains('AppLockSettingsScreen('), isTrue);
  });

  test('app_keys.dart: アプリロック用 Key が一元管理されている', () {
    final keysSource =
        File('lib/core/testing/app_keys.dart').readAsStringSync();
    for (final key in [
      'appLockScreen',
      'appLockEntry',
      'appLockGateField',
      'appLockPasscodeField',
      'appLockConfirmField',
      'appLockEnableButton',
      'appLockDisableButton',
    ]) {
      expect(keysSource.contains(key), isTrue, reason: key);
    }
  });
}
