import 'package:flutter/material.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/help/domain/help_catalog.dart';
import 'package:book_review_app/features/help/domain/help_topic.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 「遊び方・ヘルプ」— 初回チュートリアルを読み返すための画面。
///
/// 依存はゼロ。文言は [HelpCatalog]（＝チュートリアル）からのみ供給される。
class HelpScreen extends StatefulWidget {
  /// 項目の供給元（未指定ならチュートリアル由来の既定カタログ）。
  final HelpCatalog? catalog;

  const HelpScreen({super.key, this.catalog});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _controller = TextEditingController();
  late final HelpCatalog _catalog = widget.catalog ?? HelpCatalog();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topics = _catalog.search(_controller.text);

    return Scaffold(
      key: AppKeys.helpScreen,
      appBar: AppBar(title: const Text('遊び方・ヘルプ')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                key: AppKeys.helpSearchField,
                controller: _controller,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'キーワードで検索',
                  hintText: '例: レビュー、メモ',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: topics.isEmpty
                  ? const Center(
                      child: Padding(
                        key: AppKeys.helpEmpty,
                        padding: EdgeInsets.all(24),
                        child: Text(
                          '該当する項目がありません。別の言葉でお試しください。',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: topics.length,
                      itemBuilder: (context, index) =>
                          _topicTile(context, topics[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topicTile(BuildContext context, HelpTopic topic) {
    return SemanticHelper.interactive(
      testId: 'help_topic_${topic.id}',
      label: '${topic.title}の説明を開く',
      child: ExpansionTile(
        key: AppKeys.helpTopic(topic.id),
        leading: const Icon(Icons.help_outline),
        title: Text(topic.title),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                topic.body,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
