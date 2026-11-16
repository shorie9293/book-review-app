/// 本棚 AppBar のアクションを「直置き」と「その他メニュー」へ振り分ける純粋計算。
///
/// なぜ純粋層へ切り出すか:
/// 本棚の AppBar は導線が17件まで増え、実機幅360dpでは `RenderFlex overflowed` で
/// 右端の操作に到達できなかった。しかし「何件まで直置きできるか」を widget の
/// build の中で ad-hoc に判定すると、境界（幅・文字倍率・件数）の回帰を試練で
/// 撃てない。ここでは幅と件数だけを受け取り、判定を1箇所に閉じる。
library;

/// AppBar の1スロット幅（Material の最小タップ領域 48dp）。
const double kAppBarActionSlotWidth = 48.0;

/// タイトル（「本棚」）と余白のために確保する幅の基準値（文字倍率 1.0 のとき）。
const double kAppBarTitleReserveBase = 96.0;

/// 振り分けの結果。`inlineCount + overflowCount == actionCount` を不変条件とする。
class AppBarActionPlan {
  /// AppBar に直置きする件数。
  final int inlineCount;

  /// 「その他」メニューへ畳む件数。
  final int overflowCount;

  const AppBarActionPlan._(this.inlineCount, this.overflowCount);

  /// アクションが無いとき。
  const AppBarActionPlan.empty()
      : inlineCount = 0,
        overflowCount = 0;

  /// 「その他」メニューを出すか。
  bool get hasOverflow => overflowCount > 0;

  /// 幅・件数・文字倍率から振り分けを決める。
  ///
  /// - 全件が収まるなら全件直置き（従来の見た目を保つ）。
  /// - 収まらないなら「その他」ボタン1スロットを空けた上で、残りを直置きする。
  /// - 極端に狭くても直置きは最低1件残す（全操作がメニューのみになるのを避ける）。
  factory AppBarActionPlan.plan({
    required int actionCount,
    required double availableWidth,
    double slotWidth = kAppBarActionSlotWidth,
    double titleReserve = kAppBarTitleReserveBase,
    int minInline = 1,
  }) {
    if (actionCount <= 0) return const AppBarActionPlan.empty();
    final usable = availableWidth - titleReserve;
    final slots = usable <= 0 ? 0 : (usable / slotWidth).floor();
    if (actionCount <= slots) {
      return AppBarActionPlan._(actionCount, 0);
    }
    // 「その他」ボタンが1スロットを占めるため、直置きは slots-1 まで。
    final wanted = (slots - 1) < minInline ? minInline : slots - 1;
    final inline = wanted < 1
        ? 1
        : (wanted > actionCount ? actionCount : wanted);
    return AppBarActionPlan._(inline, actionCount - inline);
  }

  @override
  String toString() =>
      'AppBarActionPlan(inline: $inlineCount, overflow: $overflowCount)';
}
