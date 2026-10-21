/// 貸出の返却期限リマインダー設定値オブジェクト。
///
/// 不変（immutable）。[hour] は 0-23、[minute] は 0-59 の範囲でなければ
/// 生成時に [ArgumentError] を投げる（`assert` ではなく実行時検証）。
class LoanDueReminderSettings {
  LoanDueReminderSettings({
    this.enabled = false,
    this.hour = 9,
    this.minute = 0,
    this.updatedAt,
  }) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', '0-23 の範囲で指定せよ');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', '0-59 の範囲で指定せよ');
    }
  }

  /// 既定値: 無効・9:00。
  factory LoanDueReminderSettings.defaults() => LoanDueReminderSettings();

  final bool enabled;
  final int hour;
  final int minute;
  final DateTime? updatedAt;

  /// 永続化キー（Hive / 設定ストア共通）。
  static const String storageKey = 'loanDueReminder';

  LoanDueReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    DateTime? updatedAt,
  }) {
    return LoanDueReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  /// 型不一致・欠落・範囲外は [FormatException]。
  factory LoanDueReminderSettings.fromJson(Map<String, dynamic> json) {
    try {
      final enabled = json['enabled'];
      final hour = json['hour'];
      final minute = json['minute'];
      final updatedAt = json['updatedAt'];
      if (enabled is! bool) throw const FormatException('enabled');
      if (hour is! int) throw const FormatException('hour');
      if (minute is! int) throw const FormatException('minute');
      DateTime? updatedAtParsed;
      if (updatedAt is String) {
        updatedAtParsed = DateTime.tryParse(updatedAt);
        if (updatedAtParsed == null) throw const FormatException('updatedAt');
      } else if (updatedAt != null) {
        throw const FormatException('updatedAt');
      }
      return LoanDueReminderSettings(
        enabled: enabled,
        hour: hour,
        minute: minute,
        updatedAt: updatedAtParsed,
      );
    } on ArgumentError {
      throw const FormatException('LoanDueReminderSettings の範囲外の値');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanDueReminderSettings &&
          other.enabled == enabled &&
          other.hour == hour &&
          other.minute == minute &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(enabled, hour, minute, updatedAt);

  @override
  String toString() => 'LoanDueReminderSettings(enabled: $enabled, '
      'hour: $hour, minute: $minute, updatedAt: $updatedAt)';
}
