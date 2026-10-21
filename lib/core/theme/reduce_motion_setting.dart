import 'package:flutter/material.dart';

/// 「動きを減らす（Reduce Motion）」設定
///
/// [system] は端末のアクセシビリティ設定（`MediaQuery.disableAnimations`）に従う。
/// [off] は利用者が明示的に「動きを有効」を選んだ状態で、端末設定が
/// 動きを減らす指定でも**端末設定より優先**してアニメーションを有効化する。
/// [on] は端末設定に関わらず動きを減らす。
enum ReduceMotionSetting {
  system('system', 'システムに従う', Icons.brightness_auto_outlined),
  off('off', '動きを有効', Icons.animation),
  on('on', '動きを減らす', Icons.motion_photos_off_outlined);

  const ReduceMotionSetting(this.storageKey, this.label, this.icon);

  /// 永続化用のキー文字列
  final String storageKey;

  /// 表示用ラベル
  final String label;

  /// 表示用アイコン
  final IconData icon;

  /// 保存キーから復元する。不明値 / null は [system]。
  static ReduceMotionSetting fromStorageKey(String? key) {
    for (final setting in ReduceMotionSetting.values) {
      if (setting.storageKey == key) return setting;
    }
    return ReduceMotionSetting.system;
  }

  /// system → off → on → system の巡回。
  ReduceMotionSetting get next => switch (this) {
        ReduceMotionSetting.system => ReduceMotionSetting.off,
        ReduceMotionSetting.off => ReduceMotionSetting.on,
        ReduceMotionSetting.on => ReduceMotionSetting.system,
      };

  /// 強制する `disableAnimations` 値。
  /// [on] → true（動きを減らす）、[off] → false（動きを有効）、
  /// [system] → null（端末設定に従う）。
  bool? get forceDisableAnimations => switch (this) {
        ReduceMotionSetting.on => true,
        ReduceMotionSetting.off => false,
        ReduceMotionSetting.system => null,
      };
}

/// 設定を `MediaQueryData` に反映する。
///
/// [ReduceMotionSetting.system] の場合は端末設定を尊重し、[data] を
/// そのまま返す（同一インスタンス）。それ以外は `disableAnimations` のみ
/// 上書きする。
MediaQueryData applyReduceMotion(
  MediaQueryData data,
  ReduceMotionSetting setting,
) {
  final forced = setting.forceDisableAnimations;
  if (forced == null) return data;
  return data.copyWith(disableAnimations: forced);
}
