import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/about_info.dart';
import '../domain/external_url_opener.dart';
import 'about_app_keys.dart';
import 'external_url_launcher.dart';

/// 「アプリについて」画面。
///
/// アプリ名・バージョン、OSSライセンス、プライバシーポリシー、
/// 問い合わせ先を提示する。プライバシーポリシーと問い合わせは
/// タップで外部アプリ（ブラウザ・メール）へ渡し、開けなかった場合は
/// 従来のコピー導線（URL表示＋クリップボード）へ退避する。
class AboutScreen extends StatelessWidget {
  final AboutInfo info;

  /// クリップボード書き込み口（試練ではインメモリ実装を注入する）。
  final Future<void> Function(String value) clipboardWriter;

  /// 外部URLを開く口（試練ではフェイクを注入する）。
  final ExternalUrlOpener urlOpener;

  const AboutScreen({
    super.key,
    this.info = kAboutInfo,
    this.clipboardWriter = _defaultClipboardWriter,
    this.urlOpener = launchExternalUrl,
  });

  static Future<void> _defaultClipboardWriter(String value) {
    return Clipboard.setData(ClipboardData(text: value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AboutAppKeys.screen,
      appBar: AppBar(title: const Text('アプリについて')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Column(
            children: [
              const Icon(Icons.menu_book, size: 64),
              const SizedBox(height: 8),
              Text(
                info.appName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text('v${info.version}'),
              const SizedBox(height: 4),
              Text(info.tagline, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: AboutAppKeys.licenseButton,
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('OSSライセンス'),
                  subtitle: const Text('このアプリが利用しているOSSの一覧'),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: info.appName,
                      applicationVersion: info.version,
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  key: AboutAppKeys.privacyButton,
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('プライバシーポリシー'),
                  subtitle: Text(info.privacyPolicyUrl),
                  onTap: () => _openOrCopy(
                    context,
                    uri: externalUri(info.privacyPolicyUrl),
                    title: 'プライバシーポリシー',
                    body: '以下のURLでプライバシーポリシーを確認できます。',
                    value: info.privacyPolicyUrl,
                    label: 'プライバシーポリシーURL',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: AboutAppKeys.contactButton,
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('問い合わせ'),
                  subtitle: Text(info.contactEmail),
                  onTap: () => _openOrCopy(
                    context,
                    uri: mailtoUri(info.contactEmail),
                    title: '問い合わせ',
                    body: '下記メールアドレスまでご連絡ください。',
                    value: info.contactEmail,
                    label: '問い合わせメール',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 外部アプリで開く。開けなければ（false・例外）コピー導線へ退避する。
  Future<void> _openOrCopy(
    BuildContext context, {
    required Uri? uri,
    required String title,
    required String body,
    required String value,
    required String label,
  }) async {
    var opened = false;
    if (uri != null) {
      try {
        opened = await urlOpener(uri);
      } catch (_) {
        opened = false;
      }
    }
    if (opened || !context.mounted) return;
    await _showCopyDialog(
      context,
      title: title,
      body: body,
      value: value,
      label: label,
    );
  }

  Future<void> _showCopyDialog(
    BuildContext context, {
    required String title,
    required String body,
    required String value,
    required String label,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body),
            const SizedBox(height: 8),
            SelectableText(value),
          ],
        ),
        actions: [
          TextButton(
            key: AboutAppKeys.copyButton,
            onPressed: () => _writeClipboardAndNotify(
                dialogContext, label, value, clipboardWriter),
            child: const Text('コピー'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

/// クリップボード書き込みとフィードバックの共通処理。
///
/// 書き込みは try/catch し、失敗してもクラッシュさせない。
Future<void> _writeClipboardAndNotify(
  BuildContext context,
  String label,
  String value,
  Future<void> Function(String value) clipboardWriter,
) async {
  var copied = false;
  try {
    await clipboardWriter(value);
    copied = true;
  } catch (_) {
    copied = false;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        copied ? '$labelをクリップボードにコピーしました' : 'コピーに失敗しました',
      ),
    ),
  );
}
