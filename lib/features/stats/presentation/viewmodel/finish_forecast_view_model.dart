import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/stats/domain/reading_pace.dart';
import 'package:book_review_app/features/stats/domain/reading_pace_service.dart';

/// 読了予測に必要なデータの抽象ポート。
abstract class FinishForecastDataSource {
  Future<List<Book>> getBooks();
  Future<List<ReadingSession>> getSessions();
}

/// 既存 Hive リポジトリ2件を合成した [FinishForecastDataSource] 実装。
///
/// init は一度だけ実行する。
class HiveFinishForecastDataSource implements FinishForecastDataSource {
  final HiveBookRepository _bookRepository = HiveBookRepository();
  final HiveReadingSessionRepository _sessionRepository =
      HiveReadingSessionRepository();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _bookRepository.init();
    await _sessionRepository.init();
    _initialized = true;
  }

  @override
  Future<List<Book>> getBooks() async {
    await _ensureInit();
    return _bookRepository.getBooks();
  }

  @override
  Future<List<ReadingSession>> getSessions() async {
    await _ensureInit();
    return _sessionRepository.loadAll();
  }
}

/// 読了予測の ViewModel。
///
/// 統計基準時刻 `now` は [clock] で注入する（DateTime.now() 直読み禁止）。
class FinishForecastViewModel extends ChangeNotifier {
  /// テスト可能にするための時刻取得関数（既定は DateTime.now）。
  final DateTime Function() clock;

  FinishForecastViewModel({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  final ReadingPaceService _service = const ReadingPaceService();

  bool isLoading = false;
  List<FinishForecast>? forecasts;
  String? error;

  Future<void> load(FinishForecastDataSource source) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final books = await source.getBooks();
      final sessions = await source.getSessions();
      forecasts = _service.forecastAll(books, sessions, clock());
    } on Object catch (e) {
      error = e.toString();
      forecasts = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}