/// 読了予測のステータス。
enum ReadingPaceStatus {
  ok,
  finished,
  noPageCount,
  noPace,
}

extension ReadingPaceStatusLabel on ReadingPaceStatus {
  /// 日本語ラベル。
  String get label {
    switch (this) {
      case ReadingPaceStatus.ok:
        return '読了予測あり';
      case ReadingPaceStatus.finished:
        return '読了済み';
      case ReadingPaceStatus.noPageCount:
        return 'ページ数未登録';
      case ReadingPaceStatus.noPace:
        return 'ペース推定不能';
    }
  }
}

/// 1冊の読了予測結果。
class FinishForecast {
  final String bookId;
  final String title;
  final int currentPage;
  final int pageCount;
  final int remainingPages;

  /// 推定ページ/日（推定不能は null）。
  final double? pagesPerDay;

  /// 残り日数（推定不能は null）。
  final int? daysRemaining;

  /// 読了予定日（推定不能は null）。
  final DateTime? finishDate;
  final ReadingPaceStatus status;

  FinishForecast({
    required this.bookId,
    required this.title,
    required this.currentPage,
    required this.pageCount,
    required this.remainingPages,
    required this.pagesPerDay,
    required this.daysRemaining,
    required this.finishDate,
    required this.status,
  }) {
    if (bookId.isEmpty) {
      throw ArgumentError.value(bookId, 'bookId', 'bookId は空であってはならない');
    }
    if (remainingPages < 0) {
      throw ArgumentError.value(
        remainingPages,
        'remainingPages',
        'remainingPages は0以上でなければならない',
      );
    }
  }

  /// status に応じた日本語1行サマリ。
  String get summaryLabel {
    switch (status) {
      case ReadingPaceStatus.finished:
        return '読了済み';
      case ReadingPaceStatus.noPageCount:
        return 'ページ数が未登録です';
      case ReadingPaceStatus.noPace:
        return '読書セッションが無く推定できません';
      case ReadingPaceStatus.ok:
        final d = daysRemaining ?? 0;
        final date = finishDate;
        final dateLabel = date == null
            ? ''
            : '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
        return 'あと$d日（$dateLabel）に読了見込み';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinishForecast &&
          other.runtimeType == runtimeType &&
          other.bookId == bookId &&
          other.title == title &&
          other.currentPage == currentPage &&
          other.pageCount == pageCount &&
          other.remainingPages == remainingPages &&
          other.pagesPerDay == pagesPerDay &&
          other.daysRemaining == daysRemaining &&
          other.finishDate == finishDate &&
          other.status == status;

  @override
  int get hashCode => Object.hash(
        bookId,
        title,
        currentPage,
        pageCount,
        remainingPages,
        pagesPerDay,
        daysRemaining,
        finishDate,
        status,
      );

  @override
  String toString() =>
      'FinishForecast(bookId: $bookId, status: $status, '
      'pagesPerDay: $pagesPerDay, daysRemaining: $daysRemaining, '
      'finishDate: $finishDate)';
}
