/// 読書状態
///
/// 蔵書1冊の読書の進捗状態を表す。
/// 積読（未読）→ 読書中 → 読了 の順で遷移する。
enum ReadingStatus {
  /// 積読（未読・読書開始前）
  unread,

  /// 読書中
  reading,

  /// 読了
  finished;

  /// 画面表示用の日本語ラベル
  String get label => switch (this) {
        ReadingStatus.unread => '積読',
        ReadingStatus.reading => '読書中',
        ReadingStatus.finished => '読了',
      };

  /// 直列化用の文字列（後方互換のため enum.name を利用）
  static ReadingStatus fromStorage(Object? value) {
    if (value is! String) return ReadingStatus.unread;
    return ReadingStatus.values.asNameMap()[value] ?? ReadingStatus.unread;
  }
}
