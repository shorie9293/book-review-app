import 'package:flutter/material.dart';

import 'package:book_review_app/core/infrastructure/app_lock_settings_screen.dart';
import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/core/theme/reduce_motion_repository.dart';
import 'package:book_review_app/core/theme/reduce_motion_setting.dart';
import 'package:book_review_app/core/theme/text_scale_setting.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';
import 'package:book_review_app/features/about/presentation/about_screen.dart';
import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/presentation/backup_screen.dart';
import 'package:book_review_app/features/reminder/data/quiet_hours_repository.dart';
import 'package:book_review_app/features/reminder/infrastructure/hive_quiet_hours_repository.dart';
import 'package:book_review_app/features/reminder/presentation/quiet_hours_settings_screen.dart';
import 'package:book_review_app/features/reminder/infrastructure/notification_permission_requester.dart';
import 'package:book_review_app/features/reminder/presentation/reading_reminder_settings_screen.dart';
import 'package:book_review_app/screens/reduce_motion_settings_screen.dart';
import 'package:book_review_app/screens/text_scale_settings_screen.dart';
import 'package:book_review_app/screens/theme_mode_settings_screen.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 設定ハブ画面 — 散在する設定画面への導線を1枚に集約する。
///
/// 値とコールバックが必要な画面（テーマ／文字サイズ／動きを減らす）は
/// コンストラクタで受け取り、未指定なら既定値＋no-op で実画面を開く。
/// 画面そのものを差し替えたい場合は各 `*Builder` を注入する（試練用）。
/// バックアップはリポジトリが要るため、`backupBuilder` か
/// `backupRepository` が未指定なら案内のみ出す。
class SettingsHubScreen extends StatelessWidget {
  /// 現在のテーマ設定
  final ThemeModeSetting themeMode;

  /// テーマ変更の通知（未指定なら no-op）
  final ValueChanged<ThemeModeSetting>? onThemeModeChanged;

  /// 現在の文字サイズ倍率
  final double textScale;

  /// 文字サイズ変更の通知（未指定なら no-op）
  final ValueChanged<double>? onTextScaleChanged;

  /// 現在の「動きを減らす」設定
  final ReduceMotionSetting reduceMotion;

  /// 「動きを減らす」変更の通知
  final ValueChanged<ReduceMotionSetting>? onReduceMotionChanged;

  /// 「動きを減らす」の保存先（未指定なら実装既定＝Hive）
  final ReduceMotionRepository? reduceMotionRepository;

  /// 各項目の画面ビルダー（未指定なら実画面）
  final WidgetBuilder? themeModeBuilder;
  final WidgetBuilder? textScaleBuilder;
  final WidgetBuilder? reduceMotionBuilder;
  final WidgetBuilder? appLockBuilder;
  final WidgetBuilder? readingReminderBuilder;
  final WidgetBuilder? quietHoursBuilder;
  final WidgetBuilder? backupBuilder;
  final WidgetBuilder? aboutBuilder;

  /// バックアップの採取元（`backupBuilder` 未指定時のみ使用）
  final BackupRepository? backupRepository;

  /// 静穏時間の保存先（未指定なら実装既定＝Hive）
  final QuietHoursRepository? quietHoursRepository;

  const SettingsHubScreen({
    super.key,
    this.themeMode = ThemeModeSetting.system,
    this.onThemeModeChanged,
    this.textScale = TextScaleSetting.normalScale,
    this.onTextScaleChanged,
    this.reduceMotion = ReduceMotionSetting.system,
    this.onReduceMotionChanged,
    this.reduceMotionRepository,
    this.themeModeBuilder,
    this.textScaleBuilder,
    this.reduceMotionBuilder,
    this.appLockBuilder,
    this.readingReminderBuilder,
    this.quietHoursBuilder,
    this.backupBuilder,
    this.aboutBuilder,
    this.backupRepository,
    this.quietHoursRepository,
  });

  Widget _themeModeScreen(BuildContext _) => ThemeModeSettingsScreen(
        currentMode: themeMode,
        onModeChanged: onThemeModeChanged ?? (_) {},
      );

  Widget _textScaleScreen(BuildContext _) => TextScaleSettingsScreen(
        currentScale: textScale,
        onScaleChanged: onTextScaleChanged ?? (_) {},
      );

  Widget _reduceMotionScreen(BuildContext _) => ReduceMotionSettingsScreen(
        repository: reduceMotionRepository,
        initial: reduceMotion,
        onChanged: onReduceMotionChanged,
      );

  Widget _backupScreen(BuildContext _) => BackupScreen(
        repository: backupRepository!,
      );

  void _open(BuildContext context, WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }

  /// 項目1行を組み立てる。ビルダーが無い項目は [onUnavailable] を呼ぶ。
  Widget _item(
    BuildContext context, {
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    WidgetBuilder? builder,
    VoidCallback? onUnavailable,
  }) {
    return SemanticHelper.interactive(
      testId: 'settings_hub_item_$id',
      label: '$titleを開く',
      child: ListTile(
        key: AppKeys.settingsHubItem(id),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (builder != null) {
            _open(context, builder);
          } else {
            onUnavailable?.call();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backupBuilderResolved = backupBuilder ??
        (backupRepository == null ? null : _backupScreen);
    final quietHoursRepo = quietHoursRepository;

    return Scaffold(
      key: AppKeys.settingsHubScreen,
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          _item(
            context,
            id: 'appearance',
            icon: Icons.palette_outlined,
            title: 'テーマ',
            subtitle: 'ライト／ダーク／システム',
            builder: themeModeBuilder ?? _themeModeScreen,
          ),
          _item(
            context,
            id: 'text_scale',
            icon: Icons.format_size,
            title: '文字サイズ',
            subtitle: '小／通常／大',
            builder: textScaleBuilder ?? _textScaleScreen,
          ),
          _item(
            context,
            id: 'reduce_motion',
            icon: Icons.motion_photos_off_outlined,
            title: '動きを減らす',
            subtitle: 'アニメーションを控えめにする',
            builder: reduceMotionBuilder ?? _reduceMotionScreen,
          ),
          const Divider(),
          _item(
            context,
            id: 'app_lock',
            icon: Icons.lock_outline,
            title: 'アプリロック',
            subtitle: 'パスコードで起動を保護する',
            builder: appLockBuilder ?? (_) => const AppLockSettingsScreen(),
          ),
          _item(
            context,
            id: 'reading_reminder',
            icon: Icons.notifications_active_outlined,
            title: '読書リマインダー',
            subtitle: '通知の曜日・時刻を設定する',
            builder: readingReminderBuilder ??
                (_) => ReadingReminderSettingsScreen(
                      quietHoursRepository: quietHoursRepo,
                      // 通知権限の要求（Android 13+ は要求しないと通知が出ない）。
                      permissionRequester:
                          PlatformNotificationPermissionRequester(),
                    ),
          ),
          _item(
            context,
            id: 'quiet_hours',
            icon: Icons.bedtime_outlined,
            title: '静穏時間（おやすみモード）',
            subtitle: '通知を止める時間帯を決める',
            builder: quietHoursBuilder ??
                (_) => QuietHoursSettingsScreen(
                      repository: quietHoursRepo ??
                          HiveQuietHoursRepository(),
                    ),
          ),
          const Divider(),
          _item(
            context,
            id: 'backup',
            icon: Icons.save_alt,
            title: 'バックアップ／復元',
            subtitle: '蔵書・レビューを JSON で書き出す',
            builder: backupBuilderResolved,
            onUnavailable: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('バックアップは本棚のメニューから開けます'),
              ),
            ),
          ),
          _item(
            context,
            id: 'about',
            icon: Icons.info_outline,
            title: 'アプリについて',
            subtitle: 'バージョン・ライセンス・問い合わせ',
            builder: aboutBuilder ?? (_) => const AboutScreen(),
          ),
        ],
      ),
    );
  }
}
