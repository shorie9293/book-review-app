/// 局所暦（ローカル暦）での日付判定を一元化する純粋関数群。
///
/// ## 契約：保存形式と日付キーは別物
///
/// - **保存形式**: Hive / JSON バックアップは UTC 基準の瞬間
///   （`DateTime.toIso8601String()` の `...Z`、または epoch ミリ秒）で保持しうる。
///   これは「いつ起きたか」という *瞬間* の表現であり、タイムゾーン種別を持つ。
/// - **日付キー**: 「何年何月何日か」という *暦* の表現であり、常に
///   **ローカル暦（ユーザーの生活時間帯）** で解釈しなければならない。
///
/// この2つは別契約である。UTC 種別の [DateTime] に `.year` / `.month` / `.day`
/// を直読みすると UTC 暦が返り、JST の 00:00〜08:59 に記録されたレビュー・ノートが
/// 前日（年初なら前年）に落ちる。日付キーが必要な箇所では必ず本ファイルの
/// 関数を経由すること。
///
/// 本ファイルは IO・状態・依存を持たない純粋 Dart のみで構成する。
library;

/// [dt] をローカル暦の瞬間へ正規化する。
///
/// UTC 種別なら [DateTime.toLocal] で同じ瞬間のローカル表現へ変換し、
/// 既にローカル種別ならそのまま返す（冪等）。例外は投げない。
DateTime normalizeToLocal(DateTime dt) => dt.isUtc ? dt.toLocal() : dt;

/// [dt] のローカル暦における年月日のみ（時刻 0 時）へ正規化する。
///
/// 返り値は常にローカル種別。UTC 種別の入力でも UTC 暦ではなく
/// ローカル暦の年月日を採用する（例: JST で 11/1 00:05 の瞬間は 11/1 を返す）。
DateTime localDateOnly(DateTime dt) {
  final local = normalizeToLocal(dt);
  return DateTime(local.year, local.month, local.day);
}

/// [dt] のローカル暦における年。
int localYear(DateTime dt) => normalizeToLocal(dt).year;

/// [dt] のローカル暦における月（1〜12）。
int localMonth(DateTime dt) => normalizeToLocal(dt).month;

/// [dt] のローカル暦における日（1〜31）。
int localDay(DateTime dt) => normalizeToLocal(dt).day;

/// [a] と [b] がローカル暦で同じ年月か。
///
/// 種別（UTC / ローカル）が混在していても同じ瞬間基準で比較する。
bool isSameLocalMonth(DateTime a, DateTime b) {
  final la = normalizeToLocal(a);
  final lb = normalizeToLocal(b);
  return la.year == lb.year && la.month == lb.month;
}

/// [a] と [b] がローカル暦で同じ年か。
bool isSameLocalYear(DateTime a, DateTime b) => localYear(a) == localYear(b);

/// [dt] が null なら null、そうでなければ [localDateOnly] を返す。
DateTime? tryLocalDateOnly(DateTime? dt) => dt == null ? null : localDateOnly(dt);

/// 永続化された日時表現（ISO8601 文字列）を安全に復元する。
///
/// 契約:
/// - **絶対に例外を投げない**（破損データで起動を落とさない）。
/// - [String] 以外・空文字・空白のみ・解析不能は `null`。
/// - 解析成功時は必ず [normalizeToLocal] を経て返す。したがって
///   返り値は常に `isUtc == false` のローカル瞬間である。
///
/// 保存形式（UTC 種別の瞬間）を読み取る境界面で使い、下流へ UTC 種別を
/// 流さないための正規化点とする。
DateTime? tryParseStoredDateTime(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return null;
  return normalizeToLocal(parsed);
}

/// [dt] をローカル暦の `yyyy/M/d` 文字列にする。
///
/// ゼロ埋めしない（既存表示 `'${x.year}/${x.month}/${x.day}'` と同一出力）。
/// UTC 種別の入力でも [normalizeToLocal] を経てローカル暦を出力する。
String formatLocalDate(DateTime dt, {String separator = '/'}) {
  final local = normalizeToLocal(dt);
  return '${local.year}$separator${local.month}$separator${local.day}';
}
