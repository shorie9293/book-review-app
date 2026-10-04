/// チュートリアルのページ送り進捗を表す値オブジェクト。
///
/// 現在ページと総ページ数から表示用の数値・割合・ラベルを算出する。
/// ページ境界のクランプは各メソッド内で行う（不正値は保持しない）。
class TutorialProgress {
  /// 現在のページ番号（0 起点）。
  final int currentPage;

  /// 総ページ数。
  final int totalPages;

  /// チュートリアルの進捗を生成する。
  const TutorialProgress({required this.currentPage, required this.totalPages});

  /// 総ページ数から初期進捗（1 ページ目）を生成する。
  factory TutorialProgress.initial(int totalPages) =>
      TutorialProgress(currentPage: 0, totalPages: totalPages);

  /// 最初のページかどうか。
  bool get isFirst => currentPage == 0;

  /// 最後のページかどうか（総ページ数不正時は常に true）。
  bool get isLast => totalPages <= 0 ? true : currentPage >= totalPages - 1;

  /// 表示用ページ番号（1 起点不正時は 0）。
  int get pageNumber => totalPages <= 0 ? 0 : currentPage + 1;

  /// 読了割合（0.0〜1.0）。
  double get fraction {
    if (totalPages <= 0) return 0.0;
    final value = (currentPage + 1) / totalPages;
    if (value < 0) return 0.0;
    if (value > 1) return 1.0;
    return value;
  }

  /// "1 / 5" 形式の表示ラベル。
  String get label => '$pageNumber / $totalPages';

  /// 次ページへ進む。末尾なら自身と等価を返す。
  TutorialProgress next() {
    if (isLast) return this;
    return TutorialProgress(currentPage: currentPage + 1, totalPages: totalPages);
  }

  /// 前ページへ戻る。先頭なら自身と等価を返す。
  TutorialProgress previous() {
    if (isFirst) return this;
    return TutorialProgress(currentPage: currentPage - 1, totalPages: totalPages);
  }

  /// 指定ページへ移動（0..totalPages-1 にクランプ）。
  TutorialProgress goTo(int index) {
    if (totalPages <= 0) {
      return const TutorialProgress(currentPage: 0, totalPages: 0);
    }
    final clamped = index < 0 ? 0 : (index > totalPages - 1 ? totalPages - 1 : index);
    return TutorialProgress(currentPage: clamped, totalPages: totalPages);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TutorialProgress &&
          other.currentPage == currentPage &&
          other.totalPages == totalPages;

  @override
  int get hashCode => Object.hash(currentPage, totalPages);

  @override
  String toString() => 'TutorialProgress(currentPage: $currentPage, totalPages: $totalPages)';
}
