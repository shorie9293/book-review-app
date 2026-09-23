import 'package:flutter/material.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';

/// テーマ設定画面 — ライト／ダーク／システムの選択と永続化
class ThemeModeSettingsScreen extends StatefulWidget {
  final ThemeModeSetting currentMode;
  final ValueChanged<ThemeModeSetting> onModeChanged;

  const ThemeModeSettingsScreen({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  State<ThemeModeSettingsScreen> createState() =>
      _ThemeModeSettingsScreenState();
}

class _ThemeModeSettingsScreenState extends State<ThemeModeSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.themeModeScreen,
      appBar: AppBar(title: const Text('テーマ設定')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('アプリの外観テーマを選択できます。「システム」は端末設定に従います。'),
          ),
          for (final mode in ThemeModeSetting.values)
            RadioListTile<ThemeModeSetting>(
              key: AppKeys.themeModeOption(mode.storageKey),
              title: Text(mode.label),
              secondary: Icon(mode.icon),
              value: mode,
              groupValue: widget.currentMode,
              onChanged: (value) {
                if (value == null) return;
                widget.onModeChanged(value);
                setState(() {});
              },
            ),
        ],
      ),
    );
  }
}