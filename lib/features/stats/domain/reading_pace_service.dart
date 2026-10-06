import '../../../domain/models/book.dart';
import '../../reading/domain/reading_session.dart';
import 'reading_pace.dart';

/// 読書ペースと読了予測を算出する純粋サービス。
///
/// DateTime.now() を直読みしない——`now` は必ず引数注入する。
/// 例外を投げない契約は [forecast] / [forecastAll] が担い、
/// 入力検証はここでは最小限に留める。
class ReadingPaceService {
  const ReadingPaceService();

  static const int defaultWindowDays = 14;

  /// 直近 [windowDays] 日（[now] の日を含む）の当該書籍セッションから
  /// 推定ページ/日を返す。
  ///
  /// 分子は書籍の現在ページ（[currentPage]）——セッションモデルは
  /// 読了ページ数を持たないため、進捗は Book.currentPage で表す。
  /// 分母は「最初のセッション日と now の日の差（日数、最低1）」。
  /// セッション無し・推定値が 0 以下は null。
  ///
  /// 備考: 意味論上 currentPage が必須のため、凍結シグネチャ
  /// `(sessions, now, {windowDays})` を保ったまま後方互換の
  /// 任意名前付き引数として追加している。
  double? pagesPerDay(
    List<ReadingSession> sessions,
    DateTime now, {
    int windowDays = defaultWindowDays,
    int currentPage = 0,
  }) {
    if (windowDays <= 0) {
      throw ArgumentError.value(
        windowDays,
        'windowDays',
        'windowDays は1以上でなければならない',
      );
    }
    if (sessions.isEmpty || currentPage <= 0) {
      return null;
    }

    final today = DateTime(now.year, now.month, now.day);
    final windowStart = today.subtract(Duration(days: windowDays - 1));

    DateTime? earliest;
    for (final s in sessions) {
      final day = DateTime(
        s.startedAt.year,
        s.startedAt.month,
        s.startedAt.day,
      );
      if (day.isBefore(windowStart) || day.isAfter(today)) {
        continue;
      }
      if (earliest == null || day.isBefore(earliest)) {
        earliest = day;
      }
    }
    if (earliest == null) {
      return null;
    }

    final elapsedDays = today.difference(earliest).inDays;
    final days = elapsedDays < 1 ? 1 : elapsedDays;
    final pace = currentPage / days;
    if (pace <= 0) {
      return null;
    }
    return pace;
  }

  /// 1冊の読了予測。例外を投げない。
  FinishForecast forecast(
    Book book,
    List<ReadingSession> sessions,
    DateTime now, {
    int windowDays = defaultWindowDays,
  }) {
    final pageCount = book.pageCount;
    if (pageCount == null || pageCount <= 0) {
      return FinishForecast(
        bookId: book.id,
        title: book.title,
        currentPage: book.currentPage,
        pageCount: pageCount ?? 0,
        remainingPages: 0,
        pagesPerDay: null,
        daysRemaining: null,
        finishDate: null,
        status: ReadingPaceStatus.noPageCount,
      );
    }
    if (book.currentPage >= pageCount ||
        book.readingStatus.name == 'finished') {
      return FinishForecast(
        bookId: book.id,
        title: book.title,
        currentPage: book.currentPage,
        pageCount: pageCount,
        remainingPages: 0,
        pagesPerDay: null,
        daysRemaining: null,
        finishDate: null,
        status: ReadingPaceStatus.finished,
      );
    }
    final remainingPages = pageCount - book.currentPage;

    final bookSessions = sessions
        .where((s) => s.bookId != null && s.bookId == book.id)
        .toList(growable: false);
    final pace = pagesPerDay(
      bookSessions,
      now,
      windowDays: windowDays,
      currentPage: book.currentPage,
    );
    if (pace == null) {
      return FinishForecast(
        bookId: book.id,
        title: book.title,
        currentPage: book.currentPage,
        pageCount: pageCount,
        remainingPages: remainingPages,
        pagesPerDay: null,
        daysRemaining: null,
        finishDate: null,
        status: ReadingPaceStatus.noPace,
      );
    }

    final daysRemaining = (remainingPages / pace).ceil();
    final today = DateTime(now.year, now.month, now.day);
    final finishDate = today.add(Duration(days: daysRemaining));
    return FinishForecast(
      bookId: book.id,
      title: book.title,
      currentPage: book.currentPage,
      pageCount: pageCount,
      remainingPages: remainingPages,
      pagesPerDay: pace,
      daysRemaining: daysRemaining,
      finishDate: finishDate,
      status: ReadingPaceStatus.ok,
    );
  }

  /// 進行中（readingStatus.name == 'reading'）の書籍群の予測。
  ///
  /// finishDate 昇順（null は末尾）・同値は title 昇順→bookId 昇順の
  /// 明示的安定ソート。入力非破壊。
  List<FinishForecast> forecastAll(
    List<Book> books,
    List<ReadingSession> sessions,
    DateTime now, {
    int windowDays = defaultWindowDays,
  }) {
    final forecasts = <FinishForecast>[];
    for (final book in books) {
      if (book.readingStatus.name != 'reading') {
        continue;
      }
      forecasts.add(forecast(book, sessions, now, windowDays: windowDays));
    }

    // List.sort は安定ソートではないため、比較キーを完全に列挙する
    // （finishDate → title → bookId）ことで決定論的に保つ。
    forecasts.sort((a, b) {
      final aDate = a.finishDate;
      final bDate = b.finishDate;
      if (aDate == null && bDate != null) return 1;
      if (aDate != null && bDate == null) return -1;
      if (aDate != null && bDate != null) {
        final byDate = aDate.compareTo(bDate);
        if (byDate != 0) return byDate;
      }
      final byTitle = a.title.compareTo(b.title);
      if (byTitle != 0) return byTitle;
      return a.bookId.compareTo(b.bookId);
    });
    return forecasts;
  }
}
