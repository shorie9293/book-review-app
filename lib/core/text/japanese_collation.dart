/// 日本語書名の並び替え用キーと比較（近似かな順）。
///
/// 依存なし（`dart:core` と [foldKana] のみ）。UI・Flutter に依存しない純粋関数群。
///
/// 目的: `String.compareTo` のコードポイント順では
/// ひらがな（U+3041..）よりもカタカナ（U+30A1..）が常に後ろに来るため
/// 「書名（あ→ん）」が成立しない。ここでは一度 [foldKana] で
/// ひらがな・半角カナを全角カタカナへ畳んでから比較することで、
/// かな表記ゆれを同一視した近似のかな順（あ→ん）を得る。
///
/// 注意: 厳密な五十音順（濁点・半濁点・小書き・長音の国語辞典規則）ではなく
/// 近似である。漢字の読みは解決できないため、かな以外は別グループとして後置する。
library;

import 'kana_fold.dart';

/// 全角スペース
const int _ideographicSpace = 0x3000;

/// 半角スペース
const int _space = 0x20;

/// かなグループ（ひらがな・カタカナ・長音・半角カナ）
const int _groupKana = 0;

/// その他グループ（漢字・英字・数字・記号・空文字）
const int _groupOther = 1;

/// 書名の並び替えキーを返す。
///
/// 前後の空白除去 → [foldKana]（ひらがな/半角カナ → 全角カタカナ）
/// → 全角空白(U+3000)を半角空白へ、の順に正規化する。
/// 冪等: `titleSortKey(titleSortKey(x)) == titleSortKey(x)`。
String titleSortKey(String title) {
  final folded = foldKana(title.trim());
  return folded.replaceAll(
    String.fromCharCode(_ideographicSpace),
    String.fromCharCode(_space),
  );
}

/// 書名の所属グループを返す。かななら 0、それ以外（漢字・英字・数字・記号・空文字）なら 1。
///
/// 空文字は「その他グループの先頭」として扱う（= かなの後）。
int titleGroup(String title) {
  final key = titleSortKey(title);
  if (key.isEmpty) return _groupOther;
  return _isKana(key.runes.first) ? _groupKana : _groupOther;
}

/// 書名を日本語かな順（近似）で比較する。
///
/// グループ昇順（かな = 0 が先、漢字等 = 1 が後）→ 同一グループ内は
/// [titleSortKey] のコードポイント比較。空文字はグループ1の先頭に来る。
/// 符号反転対称: `compareJapaneseTitles(a, b) == -compareJapaneseTitles(b, a)`。
int compareJapaneseTitles(String a, String b) {
  final groupA = titleGroup(a);
  final groupB = titleGroup(b);
  if (groupA != groupB) return groupA < groupB ? -1 : 1;
  return titleSortKey(a).compareTo(titleSortKey(b));
}

/// コードポイントがかな（ひらがな・カタカナ・長音・半角カナ）かどうか。
bool _isKana(int code) {
  if (code >= 0x3041 && code <= 0x3096) return true; // ひらがな
  if (code >= 0x30A1 && code <= 0x30FA) return true; // カタカナ
  if (code == 0x30FC) return true; // 長音 ー
  if (code >= 0xFF66 && code <= 0xFF9D) return true; // 半角カナ
  return false;
}
