import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/features/crossapp/data/book_reward_event_exporter.dart';
import 'package:book_review_app/features/crossapp/data/cross_app_link_repository.dart';
import 'package:book_review_app/features/crossapp/data/reward_export_log_repository.dart';
import 'package:book_review_app/features/crossapp/domain/book_reward_event_service.dart';
import 'package:uuid/uuid.dart';

/// 読了イベント書き出しのオーケストレーション。
///
/// 読了遷移のときだけ「userId 確保 → 読了冊数算出 → イベント生成 →
/// JSONL 追記 → 送信済み記録」を順に行う。
/// best-effort が原則で、いかなる例外も外へ漏らさない（UI を止めない）。
class BookRewardExportCoordinator {
  BookRewardExportCoordinator({
    required CrossAppLinkRepository linkRepository,
    required RewardExportLogRepository logRepository,
    BookRewardEventExporter exporter = const BookRewardEventExporter(),
    String Function()? eventIdGenerator,
    DateTime Function()? clock,
  })  : _linkRepository = linkRepository,
        _logRepository = logRepository,
        _exporter = exporter,
        _eventIdGenerator = eventIdGenerator ?? _defaultEventId,
        _clock = clock ?? DateTime.now;

  static const BookRewardEventService _service = BookRewardEventService();
  static const Uuid _uuid = Uuid();

  static String _defaultEventId() => _uuid.v4();

  final CrossAppLinkRepository _linkRepository;
  final RewardExportLogRepository _logRepository;
  final BookRewardEventExporter _exporter;
  final String Function() _eventIdGenerator;
  final DateTime Function() _clock;

  /// 読了遷移なら1行書き出して true。
  ///
  /// 以下の場合は何もせず false:
  /// - 読了遷移でない
  /// - 既送信（sentKey が送信済み集合に在る）
  /// - userId が確保できない（空）
  /// - 追記に失敗した
  Future<bool> exportCompletion({
    required Book previous,
    required Book updated,
    required Iterable<Book> allBooks,
  }) async {
    try {
      if (!_service.shouldExport(previous: previous, updated: updated)) {
        return false;
      }

      final userId = (await _linkRepository.ensureUserId()).trim();
      if (userId.isEmpty) return false;

      final sentKey = _service.sentKeyOf(updated);
      final sentKeys = await _logRepository.loadSentKeys();
      if (sentKeys.contains(sentKey)) return false;

      final event = _service.buildCompletionEvent(
        userId: userId,
        book: updated,
        completedCount: _service.completedCountOf(allBooks),
        eventId: _eventIdGenerator(),
        timestamp: _clock(),
      );

      final written = await _exporter.append(event);
      if (!written) return false;

      await _logRepository.markSent(sentKey);
      return true;
    } catch (_) {
      // best-effort: 報酬連携の失敗でアプリを落とさない
      return false;
    }
  }
}
