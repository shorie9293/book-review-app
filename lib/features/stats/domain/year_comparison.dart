import 'reading_stats_service.dart';

/// 2年間（対象年と前年）の読書統計比較の不変モデル。
class YearComparison {
  /// 対象年（比較の新し方）の統計
  final ReadingStats current;

  /// 前年（比較の古い方）の統計
  final ReadingStats previous;

  const YearComparison({required this.current, required this.previous});

  /// 前年に読了データがあるか
  bool get hasPreviousData => previous.totalFinished > 0;

  /// 読了冊数の差分（対象年 - 前年）
  int get finishedDiff => current.totalFinished - previous.totalFinished;

  /// 読了ページ数の差分（対象年 - 前年）
  int get pagesDiff => current.totalPages - previous.totalPages;

  /// 著者数の差分（対象年 - 前年）
  int get authorDiff => current.authorCount - previous.authorCount;

  /// 見出しラベル（例: `2025年 → 2026年`）
  String get headLabel => '${previous.year}年 → ${current.year}年';

  /// 読了冊数の符号付き差分ラベル（例: `+3冊` / `-2冊` / `±0冊`）
  String get finishedLabel => _signed(finishedDiff, '冊');

  /// 読了ページ数の符号付き差分ラベル（例: `+300ページ` / `±0ページ`）
  String get pagesLabel => _signed(pagesDiff, 'ページ');

  /// 著者数の符号付き差分ラベル（例: `+1人` / `±0人`）
  String get authorLabel => _signed(authorDiff, '人');

  /// 符号付き差分ラベルの共通ヘルパ。
  /// 正は `+N単位`、負は `-N単位`（Nは絶対値）、0は `±0単位`。
  static String _signed(int diff, String unit) {
    if (diff == 0) return '±0$unit';
    final n = diff.abs();
    return '${diff > 0 ? '+' : '-'}$n$unit';
  }
}