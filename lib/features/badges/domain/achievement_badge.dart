/// 実績バッジコレクションのドメインモデル。
/// 実績バッジの分類。
enum AchievementCategory {
  /// 読了冊数
  reading('読了', '📕'),

  /// 連続読書日数
  streak('継続', '🔥'),

  /// ジャンル制覇
  genre('ジャンル', '🏷️'),

  /// レビュー投稿
  review('レビュー', '✍️'),

  /// 読書時間
  time('読書時間', '⏱️');

  const AchievementCategory(this.label, this.icon);

  /// 日本語ラベル（読了/継続/ジャンル/レビュー/読書時間）
  final String label;

  /// 表示用アイコン
  final String icon;

  /// カテゴリの既定単位（冊/日/ジャンル/件/分）
  String get defaultUnit => switch (this) {
        AchievementCategory.reading => '冊',
        AchievementCategory.streak => '日',
        AchievementCategory.genre => 'ジャンル',
        AchievementCategory.review => '件',
        AchievementCategory.time => '分',
      };
}

/// 実績バッジの定義（不変・const可）。
class AchievementBadgeDefinition {
  final String id;
  final String name;
  final String description;
  final AchievementCategory category;

  /// 獲得に必要な回数。
  final int requiredCount;

  /// 単位（省略時はカテゴリ既定）。
  final String unit;

  const AchievementBadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.requiredCount,
    String? unit,
  }) : unit = unit ?? '';

  /// 表示用単位（明示指定がなければカテゴリ既定）。
  String get displayUnit => unit.isEmpty ? category.defaultUnit : unit;
}

/// 1バッジあたりの進捗。
class AchievementBadgeProgress {
  /// 進捗対象のバッジ定義。
  final AchievementBadgeDefinition definition;

  /// 現在値（生値。required を超える場合もある）。
  final int current;

  AchievementBadgeProgress({
    required this.definition,
    required int current,
  }) : current = current < 0 ? 0 : current {
    if (definition.requiredCount <= 0) {
      throw ArgumentError.value(
        definition.requiredCount,
        'definition.requiredCount',
        'requiredCount は正の値である必要がある',
      );
    }
  }

  /// 必要回数。
  int get required => definition.requiredCount;

  /// 進捗率（0.0..1.0 にクランプ）。required <= 0 の場合は 1.0。
  double get ratio {
    if (required <= 0) return 1.0;
    final value = current / required;
    if (value < 0.0) return 0.0;
    if (value > 1.0) return 1.0;
    return value;
  }

  /// 進捗パーセント（0〜100）。
  int get percent {
    if (required <= 0) return 100;
    final value = (current / required * 100).round();
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
  }

  /// 獲得済みか（current >= required）。
  bool get isEarned => current >= required;

  /// 獲得までの残り回数（獲得済みは 0）。
  int get remaining {
    final value = required - current;
    return value < 0 ? 0 : value;
  }

  /// '3 / 5 冊' 形式の進捗ラベル。
  String get progressLabel => '$current / $required ${definition.displayUnit}';

  /// 獲得済みなら '獲得済み'、未獲得なら 'あと2冊' 形式。
  String get remainingLabel {
    if (isEarned) return '獲得済み';
    return 'あと$remaining${definition.displayUnit}';
  }
}

/// 実績バッジ全体のコレクション（純粋ビルダーの戻り値）。
class AchievementBadgeCollection {
  /// 全バッジの進捗（定義順にソート済み）。
  final List<AchievementBadgeProgress> progresses;

  const AchievementBadgeCollection({required this.progresses});

  /// 獲得済みバッジ。
  List<AchievementBadgeProgress> get earned =>
      progresses.where((p) => p.isEarned).toList();

  /// 未獲得バッジ。
  List<AchievementBadgeProgress> get unearned =>
      progresses.where((p) => !p.isEarned).toList();

  /// 獲得数。
  int get earnedCount => progresses.where((p) => p.isEarned).length;

  /// 総数。
  int get totalCount => progresses.length;

  /// 獲得率（0除算ガード付き）。
  double get completionRatio => totalCount == 0 ? 0.0 : earnedCount / totalCount;

  /// 未獲得のバッジが1つもない（全獲得済み）か。
  bool get isEmpty => earnedCount == 0;

  /// '6 / 15 獲得' 形式のサマリラベル。
  String get summaryLabel => '$earnedCount / $totalCount 獲得';

  /// カテゴリ別グループ（宣言順・空カテゴリも含む）。
  Map<AchievementCategory, List<AchievementBadgeProgress>> get groupByCategory {
    final map = <AchievementCategory, List<AchievementBadgeProgress>>{
      for (final category in AchievementCategory.values)
        category: <AchievementBadgeProgress>[],
    };
    for (final p in progresses) {
      map[p.definition.category]!.add(p);
    }
    return map;
  }

  /// id から進捗を検索する（見つからなければ null）。
  AchievementBadgeProgress? progress(String id) {
    for (final p in progresses) {
      if (p.definition.id == id) return p;
    }
    return null;
  }
}

/// 既定の実績バッジ定義一覧（14件）。
const List<AchievementBadgeDefinition> kAchievementBadges = [
  // 読了冊数
  AchievementBadgeDefinition(
    id: 'finished_1',
    name: '最初の一冊',
    description: '初めて本を読み終えよう',
    category: AchievementCategory.reading,
    requiredCount: 1,
  ),
  AchievementBadgeDefinition(
    id: 'finished_5',
    name: '読書の輪',
    description: '5冊読み終えよう',
    category: AchievementCategory.reading,
    requiredCount: 5,
  ),
  AchievementBadgeDefinition(
    id: 'finished_10',
    name: '本の友',
    description: '10冊読み終えよう',
    category: AchievementCategory.reading,
    requiredCount: 10,
  ),
  AchievementBadgeDefinition(
    id: 'finished_25',
    name: '蔵書王',
    description: '25冊読み終えよう',
    category: AchievementCategory.reading,
    requiredCount: 25,
  ),
  // 連続読書日数
  AchievementBadgeDefinition(
    id: 'streak_3',
    name: '三日坊主脱出',
    description: '3日連続で読書しよう',
    category: AchievementCategory.streak,
    requiredCount: 3,
  ),
  AchievementBadgeDefinition(
    id: 'streak_7',
    name: '一週間の習慣',
    description: '7日連続で読書しよう',
    category: AchievementCategory.streak,
    requiredCount: 7,
  ),
  AchievementBadgeDefinition(
    id: 'streak_30',
    name: '月間読書家',
    description: '30日連続で読書しよう',
    category: AchievementCategory.streak,
    requiredCount: 30,
  ),
  // ジャンル制覇
  AchievementBadgeDefinition(
    id: 'genre_5',
    name: '探求の始まり',
    description: '5種類のジャンルを読もう',
    category: AchievementCategory.genre,
    requiredCount: 5,
  ),
  AchievementBadgeDefinition(
    id: 'genre_10',
    name: '博識の読者',
    description: '10種類のジャンルを読もう',
    category: AchievementCategory.genre,
    requiredCount: 10,
  ),
  // レビュー投稿
  AchievementBadgeDefinition(
    id: 'review_1',
    name: '感想初心者',
    description: '初めてレビューを投稿しよう',
    category: AchievementCategory.review,
    requiredCount: 1,
  ),
  AchievementBadgeDefinition(
    id: 'review_5',
    name: '語り手',
    description: 'レビューを5件投稿しよう',
    category: AchievementCategory.review,
    requiredCount: 5,
  ),
  AchievementBadgeDefinition(
    id: 'review_10',
    name: '書評家',
    description: 'レビューを10件投稿しよう',
    category: AchievementCategory.review,
    requiredCount: 10,
  ),
  // 読書時間
  AchievementBadgeDefinition(
    id: 'time_600',
    name: '10時間の世界',
    description: '合計600分読書しよう',
    category: AchievementCategory.time,
    requiredCount: 600,
  ),
  AchievementBadgeDefinition(
    id: 'time_3000',
    name: '50時間の旅人',
    description: '合計3000分読書しよう',
    category: AchievementCategory.time,
    requiredCount: 3000,
  ),
];
