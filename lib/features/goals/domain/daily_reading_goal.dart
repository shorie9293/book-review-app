/// 読書時間の日次目標（1日の読書分数）
///
/// `0` は「未設定」を意味する。
/// 負値・非数値は読み込み時に 0 へ丸める（破損 JSON でも例外を投げない）。
library;

/// 不変の日次読書目標モデル
class DailyReadingGoal {
  /// 1日の目標読書分数（0 = 未設定）
  final int targetMinutes;

  /// 最終更新日時（ISO8601 UTC。未設定時は空文字）
  final String updatedAt;

  const DailyReadingGoal({
    this.targetMinutes = 0,
    this.updatedAt = '',
  });

  /// 未設定の目標
  const DailyReadingGoal.empty() : targetMinutes = 0, updatedAt = '';

  bool get isSet => targetMinutes > 0;

  DailyReadingGoal copyWith({int? targetMinutes, String? updatedAt}) {
    return DailyReadingGoal(
      targetMinutes: targetMinutes ?? this.targetMinutes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'targetMinutes': targetMinutes,
        'updatedAt': updatedAt,
      };

  /// 破損に強い復元（非数値・負値は 0 へ、updatedAt 欠落は '' へ）
  factory DailyReadingGoal.fromJson(Map<String, dynamic> json) {
    return DailyReadingGoal(
      targetMinutes: _safeMinutes(json['targetMinutes']),
      updatedAt: json['updatedAt'] is String ? json['updatedAt'] as String : '',
    );
  }

  static int _safeMinutes(Object? raw) {
    final value = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}') ?? 0;
    return value < 0 ? 0 : value;
  }

  @override
  bool operator ==(Object other) =>
      other is DailyReadingGoal &&
      other.targetMinutes == targetMinutes &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(targetMinutes, updatedAt);
}
