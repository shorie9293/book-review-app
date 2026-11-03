import 'package:book_review_app/features/help/domain/help_topic.dart';
import 'package:book_review_app/features/tutorial/presentation/tutorial_content.dart';

/// ヘルプ項目の集合。検索は純粋関数として提供する。
///
/// 既定の内容は [TutorialContent.pages]（＝ `TutorialStep` の label/description）
/// から生成する。チュートリアル文言の二重管理を避けるため、
/// ここに文言をハードコードしてはならない。
class HelpCatalog {
  /// `_topics` は生成時に固定された読み取り専用リスト。
  final List<HelpTopic> _topics;

  /// 任意のトピック群で構築する（未指定ならチュートリアル由来）。
  /// 試練での差し替え用であり、実画面では既定を使う。
  HelpCatalog({List<HelpTopic>? topics})
      : _topics = List<HelpTopic>.unmodifiable(topics ?? _fromTutorial());

  static List<HelpTopic> _fromTutorial() => TutorialContent.pages
      .map(
        (page) => HelpTopic(
          id: page.keyName,
          title: page.title,
          body: page.body,
        ),
      )
      .toList(growable: false);

  /// 宣言順の全項目。
  List<HelpTopic> get allTopics => _topics;

  /// 見出し・本文の部分一致検索（大文字小文字を無視）。
  ///
  /// 空クエリ（空白のみを含む）は全件、該当なしは空リストを返す。
  /// 並び順は常に宣言順を維持する。
  List<HelpTopic> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return _topics;
    return _topics
        .where(
          (topic) =>
              topic.title.toLowerCase().contains(needle) ||
              topic.body.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }
}
