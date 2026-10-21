// 親探針（合成の不変条件）: 画面→リポジトリ→再読込→MediaQuery までが一本に繋がるか。
import 'dart:io';

import 'package:book_review_app/core/theme/reduce_motion_repository.dart';
import 'package:book_review_app/core/theme/reduce_motion_setting.dart';
import 'package:book_review_app/screens/reduce_motion_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('合成: 端末が動きを許可していても on なら disableAnimations=true', () {
    const platform = MediaQueryData(disableAnimations: false);
    expect(applyReduceMotion(platform, ReduceMotionSetting.on).disableAnimations,
        isTrue);
    expect(applyReduceMotion(platform, ReduceMotionSetting.off).disableAnimations,
        isFalse);
    expect(
        applyReduceMotion(platform, ReduceMotionSetting.system).disableAnimations,
        isFalse);
    expect(
        applyReduceMotion(const MediaQueryData(disableAnimations: true),
                ReduceMotionSetting.system)
            .disableAnimations,
        isTrue);
    final src = MediaQueryData(textScaler: const TextScaler.linear(1.3));
    expect(
        applyReduceMotion(src, ReduceMotionSetting.on).textScaler.scale(10),
        closeTo(13, 0.001));
  });

  testWidgets('画面で選ぶ→リポジトリ保存→onChanged通知→再読込', (tester) async {
    final repo = InMemoryReduceMotionRepository();
    ReduceMotionSetting? notified;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReduceMotionSettingsScreen(
          repository: repo,
          initial: ReduceMotionSetting.system,
          onChanged: (v) => notified = v,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('reduce_motion_option_on')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.saved, ReduceMotionSetting.on,
        reason: '画面の選択がリポジトリ保存へ到達していない');
    expect(notified, ReduceMotionSetting.on, reason: 'ルートへ通知されていない');
    final loaded = await repo.load();
    final applied =
        applyReduceMotion(const MediaQueryData(disableAnimations: false), loaded!);
    expect(applied.disableAnimations, isTrue, reason: 'MediaQueryへ反映されない');
  });

  test('根部配線: main.dart が applyReduceMotion を通している', () {
    final src = File('lib/main.dart').readAsStringSync();
    expect(src.contains('applyReduceMotion'), isTrue,
        reason: 'main.dart の builder に applyReduceMotion が無い（設定が画面で止まっている）');
    expect(src.contains('_reduceMotion'), isTrue);
  });
}
