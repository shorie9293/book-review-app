/// 走行中の読書セッションの下書き（純粋・I/O なし）。
///
/// 画面の再生成や OS による破棄でタイマー状態が消えると、読書時間の計測が
/// 意図せず途切れる。そこで開始時刻だけを端末に退避し、復帰時に継続する。
library;

/// 走行中の読書セッションの開始時刻を保持する下書き。
///
/// 保存は「UTC の瞬間」だけを行い、暦（年月日）の読み替えはしない。
/// 端末のタイムゾーンが変わっても経過時間の計算が狂わないため。
class ReadingSessionDraft {
  /// セッション開始時刻。
  final DateTime startedAt;

  const ReadingSessionDraft({required this.startedAt});

  /// JSON へ変換する。開始時刻は UTC 瞬間の ISO8601 文字列にする。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'startedAt': startedAt.toUtc().toIso8601String(),
      };

  /// JSON から復元する。**決して throw しない**。
  ///
  /// 壊れ値・欠損・型違い・解釈不能な日時はすべて null（＝下書き無し）と
  /// みなす。下書きは「消えても本編が壊れない」補助データゆえ、
  /// 復元の失敗でアプリを止めてはならない。
  ///
  /// 受理するのは [toJson] が書く正準形（UTC 瞬間）のみ。Dart の日時解釈は
  /// 範囲外の値を黙って繰り上げる（13月→翌年2月など）ため、往復文字列が
  /// 一致しないものは壊れ値として捨て、開始時刻が勝手にずれるのを防ぐ。
  static ReadingSessionDraft? tryFromJson(Object? json) {
    try {
      if (json is! Map) return null;
      final raw = json['startedAt'];
      if (raw is! String) return null;
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return null;
      // 正準形（UTC 瞬間の ISO8601）でなければ受け入れない。
      if (parsed.toUtc().toIso8601String() != raw) return null;
      return ReadingSessionDraft(startedAt: parsed.toUtc());
    } catch (_) {
      return null;
    }
  }

  /// 経過分（最低 1 分）。未来時刻や時計巻き戻りでも throw せず 1 を返す。
  int elapsedMinutes(DateTime now) {
    final minutes = now.difference(startedAt).inMinutes;
    return minutes < 1 ? 1 : minutes;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingSessionDraft && other.startedAt == startedAt;

  @override
  int get hashCode => startedAt.hashCode;

  @override
  String toString() => 'ReadingSessionDraft(startedAt: $startedAt)';
}
