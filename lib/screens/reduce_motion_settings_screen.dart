import 'package:flutter/material.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/core/theme/reduce_motion_repository.dart';
import 'package:book_review_app/core/theme/reduce_motion_setting.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 「動きを減らす」設定画面 — システム／動きを有効／動きを減らす の3択と永続化
class ReduceMotionSettingsScreen extends StatefulWidget {
  /// 保存先リポジトリ（未指定なら Hive 実装）
  final ReduceMotionRepository? repository;

  /// 現在の設定（未指定ならシステム従属）
  final ReduceMotionSetting? initial;

  /// 変更通知（上位の State で再描画するため）
  final ValueChanged<ReduceMotionSetting>? onChanged;

  const ReduceMotionSettingsScreen({
    super.key,
    this.repository,
    this.initial,
    this.onChanged,
  });

  @override
  State<ReduceMotionSettingsScreen> createState() =>
      _ReduceMotionSettingsScreenState();
}

class _ReduceMotionSettingsScreenState extends State<ReduceMotionSettingsScreen> {
  late final ReduceMotionRepository _repository =
      widget.repository ?? const ReduceMotionRepository();
  late ReduceMotionSetting _setting =
      widget.initial ?? ReduceMotionSetting.system;

  /// 選択を反映し、永続化して上位へ通知する。
  Future<void> _select(ReduceMotionSetting setting) async {
    setState(() => _setting = setting);
    widget.onChanged?.call(setting);
    await _repository.save(setting);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.reduceMotionScreen,
      appBar: AppBar(title: const Text('動きを減らす')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('画面のアニメーションを控えめにできます。「システムに従う」は端末の設定に従います。'),
          ),
          for (final setting in ReduceMotionSetting.values)
            SemanticHelper.interactive(
              testId: 'reduce_motion_option_${setting.storageKey}',
              label: '動き: ${setting.label}',
              child: RadioListTile<ReduceMotionSetting>(
                key: ValueKey('reduce_motion_option_${setting.storageKey}'),
                title: Text(setting.label),
                secondary: Icon(setting.icon),
                value: setting,
                groupValue: _setting,
                onChanged: (value) {
                  if (value == null) return;
                  _select(value);
                },
              ),
            ),
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('アクセシビリティについて',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    '動きで気分が悪くなる方のために、WCAG 2.3.3（アニメーションによる動き）では'
                    '動きを止められる手段を提供することが求められています。'
                    '「動きを減らす」を選ぶと画面遷移や装飾のアニメーションが抑制されます。'
                    '「動きを有効」は端末設定より優先されます。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
