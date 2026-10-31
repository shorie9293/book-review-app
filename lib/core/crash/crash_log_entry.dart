/// 端末内クラッシュログの1件（純粋モデル）。
///
/// 保存先に依存しない値オブジェクト。JSON 化・復元・等価比較のみを持ち、
/// 副作用（時刻取得・ファイル入出力）は一切持たない。
class CrashLogEntry {
  /// 発生時刻（保存された値そのまま。表示時に local へ変換する）。
  final DateTime timestamp;

  /// 種別（'flutter' / 'platform' / 'zone' / 'widget' など）。
  final String kind;

  /// 例外メッセージ（先頭 200 文字まで）。
  final String message;

  /// スタックの先頭 10 フレーム（1行1フレーム）。
  final String stackTop;

  /// メッセージの最大文字数。
  static const int maxMessageLength = 200;

  /// スタックの最大フレーム数。
  static const int maxStackFrames = 10;

  const CrashLogEntry({
    required this.timestamp,
    required this.kind,
    required this.message,
    this.stackTop = '',
  });

  /// 例外から1件を組み立てる（切り詰めはここで行う）。
  factory CrashLogEntry.capture({
    required DateTime timestamp,
    required String kind,
    required Object error,
    StackTrace? stack,
  }) {
    return CrashLogEntry(
      timestamp: timestamp,
      kind: kind,
      message: truncateMessage('$error'),
      stackTop: truncateStack(stack),
    );
  }

  /// メッセージを [maxMessageLength] 文字までに切り詰める。
  static String truncateMessage(String raw) {
    if (raw.length <= maxMessageLength) return raw;
    return raw.substring(0, maxMessageLength);
  }

  /// スタックの先頭 [maxStackFrames] フレームだけを残す。null は空文字。
  static String truncateStack(StackTrace? stack) {
    if (stack == null) return '';
    final lines = '$stack'
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return '';
    final head = lines.length > maxStackFrames
        ? lines.sublist(0, maxStackFrames)
        : lines;
    return head.join('\n');
  }

  /// 保存用 JSON へ変換する。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'ts': timestamp.toIso8601String(),
        'kind': kind,
        'message': message,
        'stack': stackTop,
      };

  /// JSON から復元する。壊れていれば null（例外は投げない）。
  static CrashLogEntry? fromJson(Map<String, dynamic> json) {
    final ts = json['ts'];
    final kind = json['kind'];
    final message = json['message'];
    if (ts is! String || kind is! String || message is! String) return null;
    final parsed = DateTime.tryParse(ts);
    if (parsed == null) return null;
    final stack = json['stack'];
    return CrashLogEntry(
      timestamp: parsed,
      kind: kind,
      message: message,
      stackTop: stack is String ? stack : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CrashLogEntry &&
      other.timestamp == timestamp &&
      other.kind == kind &&
      other.message == message &&
      other.stackTop == stackTop;

  @override
  int get hashCode => Object.hash(timestamp, kind, message, stackTop);

  @override
  String toString() => 'CrashLogEntry($kind, $timestamp, $message)';
}
