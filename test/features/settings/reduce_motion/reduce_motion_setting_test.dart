import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/theme/reduce_motion_setting.dart';

void main() {
  group('ReduceMotionSetting', () {
    test('fromStorageKey: 既知のキーを復元する', () {
      expect(ReduceMotionSetting.fromStorageKey('system'),
          ReduceMotionSetting.system);
      expect(ReduceMotionSetting.fromStorageKey('off'), ReduceMotionSetting.off);
      expect(ReduceMotionSetting.fromStorageKey('on'), ReduceMotionSetting.on);
    });

    test('fromStorageKey: null / 未知のキーは system', () {
      expect(ReduceMotionSetting.fromStorageKey(null),
          ReduceMotionSetting.system);
      expect(ReduceMotionSetting.fromStorageKey('unknown'),
          ReduceMotionSetting.system);
      expect(ReduceMotionSetting.fromStorageKey(''),
          ReduceMotionSetting.system);
    });

    test('next は system→off→on→system を巡回する', () {
      expect(ReduceMotionSetting.system.next, ReduceMotionSetting.off);
      expect(ReduceMotionSetting.off.next, ReduceMotionSetting.on);
      expect(ReduceMotionSetting.on.next, ReduceMotionSetting.system);
    });

    test('forceDisableAnimations: on=true / off=false / system=null', () {
      expect(ReduceMotionSetting.on.forceDisableAnimations, isTrue);
      expect(ReduceMotionSetting.off.forceDisableAnimations, isFalse);
      expect(ReduceMotionSetting.system.forceDisableAnimations, isNull);
    });

    test('storageKey と label が定義されている', () {
      expect(ReduceMotionSetting.on.storageKey, 'on');
      expect(ReduceMotionSetting.on.label, '動きを減らす');
      expect(ReduceMotionSetting.off.label, '動きを有効');
      expect(ReduceMotionSetting.system.label, 'システムに従う');
    });

    test('applyReduceMotion: system はデータをそのまま返す', () {
      const data = MediaQueryData(disableAnimations: true);
      final result = applyReduceMotion(data, ReduceMotionSetting.system);
      expect(identical(result, data), isTrue);
      expect(result.disableAnimations, isTrue);
    });

    test('applyReduceMotion: on は disableAnimations=true を強制する', () {
      const data = MediaQueryData(disableAnimations: false);
      final result = applyReduceMotion(data, ReduceMotionSetting.on);
      expect(result.disableAnimations, isTrue);
      // 他のフィールドは保たれる
      expect(result.size, data.size);
    });

    test('applyReduceMotion: off は disableAnimations=false を強制する', () {
      const data = MediaQueryData(disableAnimations: true);
      final result = applyReduceMotion(data, ReduceMotionSetting.off);
      expect(result.disableAnimations, isFalse);
    });
  });
}
