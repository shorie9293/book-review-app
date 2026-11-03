import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// lib 配下に生の `print(` / `debugPrint(` が増えていないことを監視する静的ゲート。
///
/// 本番ログの垂れ流し再発防止。許容件数は `tool/print_baseline.txt` に記す
/// （ロガー内部の debugPrint 1件のみを想定）。
void main() {
  test('lib 配下の生 print/debugPrint は baseline 以下', () {
    final pattern = RegExp(r'\b(debugPrint|print)\s*\(');
    final offenders = <String>[];
    var total = 0;

    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ が見つからない');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          total++;
          offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    final baselineFile = File('tool/print_baseline.txt');
    expect(baselineFile.existsSync(), isTrue,
        reason: 'tool/print_baseline.txt が無い');
    final baseline = int.parse(baselineFile.readAsStringSync().trim());

    expect(
      total,
      lessThanOrEqualTo(baseline),
      reason: '生 print/debugPrint が $total件（許容 $baseline件）。'
          'AppLogger (lib/core/logging/app_logger.dart) を使うこと:\n'
          '${offenders.join('\n')}',
    );
  });
}
