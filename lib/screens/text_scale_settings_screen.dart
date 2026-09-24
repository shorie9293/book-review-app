import 'package:flutter/material.dart';
import 'package:book_review_app/core/theme/text_scale_setting.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 文字サイズ設定画面 — 3段階（小／通常／大）の選択と永続化
class TextScaleSettingsScreen extends StatefulWidget {
  final double currentScale;
  final ValueChanged<double> onScaleChanged;

  const TextScaleSettingsScreen({
    super.key,
    required this.currentScale,
    required this.onScaleChanged,
  });

  @override
  State<TextScaleSettingsScreen> createState() =>
      _TextScaleSettingsScreenState();
}

class _TextScaleSettingsScreenState extends State<TextScaleSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final current = TextScaleSetting.normalized(widget.currentScale);
    return Scaffold(
      appBar: AppBar(title: const Text('文字サイズ設定')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('アプリ全体の文字サイズを選択できます。'),
          ),
          // 現在の倍率での見本表示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('見本: 書籍タイトル',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('これは本文の表示サンプルです。',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
          for (final preset in TextScaleSetting.presets)
            SemanticHelper.interactive(
              testId:
                  'text_scale_option_${preset.scale.toString().replaceAll('.', '_')}',
              label: '文字サイズ: ${preset.label}',
              child: RadioListTile<double>(
                key: Key('text_scale_${preset.scale}'),
                title: Text(preset.label),
                value: preset.scale,
                groupValue: current,
                onChanged: (value) {
                  if (value == null) return;
                  widget.onScaleChanged(value);
                  setState(() {});
                },
              ),
            ),
        ],
      ),
    );
  }
}
