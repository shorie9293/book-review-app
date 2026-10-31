import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 配線テスト: 起動経路が未捕捉例外の受け皿を通り、
/// 設定ハブからクラッシュログへ到達できること。
void main() {
  test('main.dart は runZonedGuarded で bootstrap を包み、crash guard を設置する', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source.contains('runZonedGuarded('), isTrue);
    expect(source.contains('await bootstrap()'), isTrue);
    expect(source.contains('installCrashGuard(logger: crashLogger)'), isTrue);
    expect(
        source.contains('_crashLogger?.record(error, stack, kind: \'zone\')'),
        isTrue);
    // 既存の初期化順序と AppLockGate(ErrorBoundary) 配線は不変。
    expect(source.contains('unlockedBuilder: (context) => ErrorBoundary('),
        isTrue);
    expect(source.indexOf('WidgetsFlutterBinding.ensureInitialized()'),
        lessThan(source.indexOf('await Hive.initFlutter()')));
  });

  test('設定ハブに「不具合の報告」項目がある（AppBar アイコンは増やさない）', () {
    final source =
        File('lib/features/settings/presentation/settings_hub_screen.dart')
            .readAsStringSync();

    expect(source.contains("id: 'crash_log'"), isTrue);
    expect(source.contains('不具合の報告'), isTrue);
    expect(source.contains('CrashLogScreen('), isTrue);
  });
}
