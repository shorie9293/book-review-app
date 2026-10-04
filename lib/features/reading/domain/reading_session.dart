/// 読書セッション（モデル）。
///
/// 1回の読書（開始時刻と継続時間）を表す。
class ReadingSession {
  final String id;

  /// 紐づく蔵書（任意）。
  final String? bookId;

  /// 表示用の書名スナップショット。
  final String? bookTitle;

  final DateTime startedAt;

  /// 継続時間（分）。1以上。
  final int durationMinutes;

  ReadingSession({
    required this.id,
    this.bookId,
    this.bookTitle,
    required this.startedAt,
    required this.durationMinutes,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'id は空であってはならない');
    }
    if (durationMinutes <= 0) {
      throw ArgumentError.value(
        durationMinutes,
        'durationMinutes',
        'durationMinutes は1以上でなければならない',
      );
    }
  }

  /// セッション終了時刻。
  DateTime get endedAt => startedAt.add(Duration(minutes: durationMinutes));

  /// 継続時間を時間単位に丸めた値（切り捨て）。
  int get durationHoursRounded => durationMinutes ~/ 60;

  /// 人間可読な継続時間ラベル（'1時間30分' / '45分'）。
  String get durationLabel {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (hours == 0) return '$minutes分';
    if (minutes == 0) return '$hours時間';
    return '$hours時間$minutes分';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'startedAt': startedAt.toIso8601String(),
        'durationMinutes': durationMinutes,
      };

  factory ReadingSession.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final startedAtRaw = json['startedAt'];
    final durationMinutesRaw = json['durationMinutes'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('ReadingSession: id が不正です');
    }
    if (startedAtRaw is! String) {
      throw const FormatException('ReadingSession: startedAt が不正です');
    }
    final startedAt = DateTime.tryParse(startedAtRaw);
    if (startedAt == null) {
      throw const FormatException('ReadingSession: startedAt を解釈できません');
    }
    if (durationMinutesRaw is! int || durationMinutesRaw <= 0) {
      throw const FormatException(
        'ReadingSession: durationMinutes が不正です',
      );
    }
    final bookId = json['bookId'];
    final bookTitle = json['bookTitle'];
    return ReadingSession(
      id: id,
      bookId: bookId is String ? bookId : null,
      bookTitle: bookTitle is String ? bookTitle : null,
      startedAt: startedAt,
      durationMinutes: durationMinutesRaw,
    );
  }

  static const Object _unset = Object();

  ReadingSession copyWith({
    String? id,
    Object? bookId = _unset,
    Object? bookTitle = _unset,
    DateTime? startedAt,
    int? durationMinutes,
  }) {
    return ReadingSession(
      id: id ?? this.id,
      bookId: bookId == _unset ? this.bookId : bookId as String?,
      bookTitle: bookTitle == _unset ? this.bookTitle : bookTitle as String?,
      startedAt: startedAt ?? this.startedAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingSession &&
          other.id == id &&
          other.bookId == bookId &&
          other.bookTitle == bookTitle &&
          other.startedAt == startedAt &&
          other.durationMinutes == durationMinutes;

  @override
  int get hashCode => Object.hash(id, bookId, bookTitle, startedAt,
      durationMinutes);

  @override
  String toString() =>
      'ReadingSession(id: $id, bookId: $bookId, startedAt: $startedAt, '
      'durationMinutes: $durationMinutes)';
}
