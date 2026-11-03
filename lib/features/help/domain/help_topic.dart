/// ヘルプ1項目分の不変データ。
///
/// 画面から独立した純粋な値オブジェクト。文言はチュートリアル
/// （`TutorialContent`）を唯一の出所とし、ここには複製を持たない。
class HelpTopic {
  /// 項目の一意な識別子（試練用 Key の元になる）。
  final String id;

  /// 見出し。
  final String title;

  /// 本文。
  final String body;

  /// 関連する画面の Key 名（あれば）。導線を張る際の手掛かり。
  final String? relatedScreenKey;

  const HelpTopic({
    required this.id,
    required this.title,
    required this.body,
    this.relatedScreenKey,
  });
}
