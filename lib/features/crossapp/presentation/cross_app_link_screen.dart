import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:book_review_app/features/crossapp/data/cross_app_link_repository.dart';
import 'package:book_review_app/features/crossapp/data/reward_export_log_repository.dart';
import 'package:book_review_app/features/crossapp/domain/cross_app_link_code.dart';
import 'package:book_review_app/features/crossapp/presentation/cross_app_link_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// クロスアプリ連携画面。
///
/// この端末の userId（初回は採番）の先頭8文字を「連携コード」として提示し、
/// rpg-task の設定画面で手入力してもらう。読了イベントの `user_id` も
/// 同じ userId なので、rpg-task 側は前方一致で照合できる。
///
/// [logRepository] を渡したときだけ「送信済みの読了イベント: N件」を出す
/// （未指定なら件数行そのものを出さない）。
class CrossAppLinkScreen extends StatefulWidget {
  /// userId（= 連携コードの元）の保管庫
  final CrossAppLinkRepository linkRepository;

  /// 書き出し済みイベントの記録（未指定なら件数は出さない）
  final RewardExportLogRepository? logRepository;

  /// クリップボード書き込み口（未指定なら [Clipboard.setData]）
  final Future<void> Function(String value)? clipboardWriter;

  const CrossAppLinkScreen({
    super.key,
    required this.linkRepository,
    this.logRepository,
    this.clipboardWriter,
  });

  @override
  State<CrossAppLinkScreen> createState() => _CrossAppLinkScreenState();
}

class _CrossAppLinkScreenState extends State<CrossAppLinkScreen> {
  /// 8文字の連携コード（読み込み前は空）
  String _code = '';

  /// 読み込み完了フラグ
  bool _loaded = false;

  /// 送信済み読了イベント件数（logRepository 未指定なら null）
  int? _sentCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String code = '';
    int? sentCount;
    try {
      code = linkCodeOf(await widget.linkRepository.ensureUserId());
    } catch (_) {
      code = '';
    }
    final logRepository = widget.logRepository;
    if (logRepository != null) {
      try {
        sentCount = (await logRepository.loadSentKeys()).length;
      } catch (_) {
        sentCount = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _code = code;
      _sentCount = sentCount;
      _loaded = true;
    });
  }

  Future<void> _copy() async {
    final writer = widget.clipboardWriter ?? _defaultClipboardWriter;
    try {
      await writer(_code);
    } catch (_) {
      // best-effort: コピーできなくても画面を壊さない
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('連携コードをコピーしました')),
    );
  }

  static Future<void> _defaultClipboardWriter(String value) {
    return Clipboard.setData(ClipboardData(text: value));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: CrossAppLinkKeys.screen,
      appBar: AppBar(title: const Text('クロスアプリ連携')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SemanticHelper.navigation(
                testId: 'cross_app_link_sec_header',
                label: 'クロスアプリ連携',
                child: Text('クロスアプリ連携', style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: 16),
              Text('連携コード', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SemanticHelper.container(
                testId: 'cross_app_link_sec_code',
                label: '連携コード ${_code.isEmpty ? '読み込み中' : _code}',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _loaded ? _code : '----',
                    key: CrossAppLinkKeys.linkCode,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SemanticHelper.interactive(
                testId: 'cross_app_link_btn_copy',
                label: '連携コードをコピー',
                child: ElevatedButton.icon(
                  key: CrossAppLinkKeys.copyButton,
                  onPressed: _loaded && _code.isNotEmpty ? _copy : null,
                  icon: const Icon(Icons.copy),
                  label: const Text('コピー'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'rpg-task の連携コード欄にこの8文字を入力すると、'
                '読了がコイン・EXP・称号に反映されます',
              ),
              if (_sentCount != null) ...[
                const SizedBox(height: 16),
                SemanticHelper.container(
                  testId: 'cross_app_link_sec_sent',
                  label: '送信済みの読了イベント $_sentCount件',
                  child: Text(
                    '送信済みの読了イベント: $_sentCount件',
                    key: CrossAppLinkKeys.sentCount,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
