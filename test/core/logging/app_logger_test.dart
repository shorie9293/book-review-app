import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/logging/app_logger.dart';

/// [AppLogger] の試練。
///
/// 本番（release）で verbose ログを垂れ流さないこと、
/// 警告・異常は必ず残すこと、sink が壊れてもアプリを落とさないことを担保する。
void main() {
  group('AppLogger', () {
    test('isDebug=true のとき debug は [DEBUG] タグ付きで出す', () {
      final lines = <String>[];
      final log = AppLogger(isDebug: true, sink: lines.add);

      log.debug('読み込み開始');

      expect(lines, hasLength(1));
      expect(lines.single, contains('[DEBUG]'));
      expect(lines.single, contains('読み込み開始'));
    });

    test('isDebug=false のとき debug は無出力', () {
      final lines = <String>[];
      final log = AppLogger(isDebug: false, sink: lines.add);

      log.debug('読み込み開始');

      expect(lines, isEmpty);
    });

    test('info は isDebug に従い、true なら [INFO] タグ付きで出す', () {
      final shown = <String>[];
      AppLogger(isDebug: true, sink: shown.add).info('同期完了');
      expect(shown.single, contains('[INFO]'));
      expect(shown.single, contains('同期完了'));

      final hidden = <String>[];
      AppLogger(isDebug: false, sink: hidden.add).info('同期完了');
      expect(hidden, isEmpty);
    });

    test('warn は isDebug=false でも [WARN] と例外・スタックを出す', () {
      final lines = <String>[];
      final log = AppLogger(isDebug: false, sink: lines.add);
      final stack = StackTrace.current;

      log.warn('バックアップ失敗', StateError('disk full'), stack);

      expect(lines, hasLength(1));
      expect(lines.single, contains('[WARN]'));
      expect(lines.single, contains('バックアップ失敗'));
      expect(lines.single, contains('disk full'));
      expect(lines.single, contains(stack.toString().split('\n').first));
    });

    test('error は isDebug=false でも [ERROR] を出し、例外なしでも動く', () {
      final lines = <String>[];
      final log = AppLogger(isDebug: false, sink: lines.add);

      log.error('初期化失敗');
      log.error('通知失敗', Exception('boom'));

      expect(lines, hasLength(2));
      expect(lines.first, contains('[ERROR]'));
      expect(lines.first, contains('初期化失敗'));
      expect(lines.last, contains('boom'));
    });

    test('sink が例外を投げても呼び出し側へ伝播しない', () {
      void brokenSink(String _) => throw StateError('sink broken');
      final log = AppLogger(isDebug: true, sink: brokenSink);

      expect(() => log.debug('a'), returnsNormally);
      expect(() => log.info('b'), returnsNormally);
      expect(() => log.warn('c', Exception('e')), returnsNormally);
      expect(() => log.error('d', Exception('e')), returnsNormally);
    });

    test('既定の appLog は kDebugMode に従う（試練環境は debug）', () {
      final lines = <String>[];
      // 既定 sink は debugPrint のため、検証は isDebug の既定値で行う。
      final log = AppLogger(sink: lines.add);

      log.debug('既定');

      expect(log.isDebug, isTrue);
      expect(lines.single, contains('[DEBUG]'));
    });
  });
}
