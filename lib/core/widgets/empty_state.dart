/// 空状態（0件）の共通部品。
///
/// 文言は呼出側が渡す（この部品は文言を持たない）。
/// 「読み込み失敗」（LoadErrorView）とは別物として扱う。
library;

import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 空状態の見出し・説明・行動を表す純粋データ。
///
/// 不変条件は assert ではなくコンストラクタ本体で [ArgumentError] として弾く
/// （リリースビルドでも壊れた空状態を作らせないため）。
class EmptyStateSpec {
  EmptyStateSpec({
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', '空状態の見出しは必須です');
    }
    if (actionLabel != null && actionLabel!.trim().isEmpty) {
      throw ArgumentError.value(
        actionLabel,
        'actionLabel',
        '行動ボタンの文言は空にできません',
      );
    }
    // ボタン文言だけ／動作だけ、という片手落ちを許さない。
    if ((actionLabel == null) != (onAction == null)) {
      throw ArgumentError(
        'actionLabel と onAction は両方指定するか、両方省略するかしてください',
      );
    }
  }

  /// 空状態の見出し（必須・空文字不可）。
  final String title;

  /// 見出しを補足する説明（任意）。
  final String? description;

  /// 行動ボタンの文言（[onAction] と同時指定）。
  final String? actionLabel;

  /// 行動ボタン押下時の動作（[actionLabel] と同時指定）。
  final VoidCallback? onAction;

  /// 行動ボタンを出せるか。
  bool get hasAction => actionLabel != null && onAction != null;
}

/// 空状態の表示。[EmptyStateSpec] の内容を描くだけの薄い View。
///
/// 試練で一意に掴めるよう [Key] を必須にしている。
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required super.key,
    required this.spec,
    this.icon,
  });

  final EmptyStateSpec spec;

  /// 見出しの上に出すアイコン（任意）。
  final IconData? icon;

  /// 行動ボタンの Key（画面側の試練から叩く）。
  static const Key actionButtonKey = Key('empty_state_action_button');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final label = spec.actionLabel;
    final onAction = spec.onAction;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
            ],
            Text(
              spec.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (spec.description != null) ...[
              const SizedBox(height: 8),
              Text(
                spec.description!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ],
            // 文言と動作が揃っているときだけボタンを描く。
            if (label != null && onAction != null) ...[
              const SizedBox(height: 16),
              SemanticHelper.interactive(
                testId: 'empty_state_action',
                label: label,
                child: FilledButton.tonal(
                  key: actionButtonKey,
                  onPressed: onAction,
                  child: Text(label),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
