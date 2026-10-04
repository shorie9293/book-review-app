import 'package:hive/hive.dart';

/// チュートリアル完了状態のリポジトリ抽象。
///
/// UI 層はこの抽象に依存し、永続化の詳細を知らない
/// （依存性注入によりテスト時に差し替え可能）。
abstract class TutorialRepository {
  /// チュートリアル完了済みなら true。
  Future<bool> isCompleted();

  /// チュートリアルを完了として記録する。
  Future<void> markCompleted();

  /// 完了状態をリセットする（再表示用）。
  Future<void> reset();
}

/// Hive による永続化実装。
///
/// 既存の 'settings' ボックス（String 型）と型衝突しないため、
/// 専用の 'tutorial_settings' ボックス（bool 型）を使用する。
class HiveTutorialRepository implements TutorialRepository {
  /// ボックス名。
  static const String boxName = 'tutorial_settings';

  /// 完了フラグのキー。
  static const String key = 'book_review_tutorial_completed';

  const HiveTutorialRepository();

  @override
  Future<bool> isCompleted() async {
    final box = await Hive.openBox<bool>(boxName);
    return box.get(key) ?? false;
  }

  @override
  Future<void> markCompleted() async {
    final box = await Hive.openBox<bool>(boxName);
    await box.put(key, true);
  }

  @override
  Future<void> reset() async {
    final box = await Hive.openBox<bool>(boxName);
    await box.delete(key);
  }
}

/// テスト・プレビュー用のインメモリ実装。
class InMemoryTutorialRepository implements TutorialRepository {
  bool _completed;

  /// 初期完了状態を指定して生成する。
  InMemoryTutorialRepository({bool completed = false}) : _completed = completed;

  @override
  Future<bool> isCompleted() async => _completed;

  @override
  Future<void> markCompleted() async {
    _completed = true;
  }

  @override
  Future<void> reset() async {
    _completed = false;
  }
}

/// 何もしない実装。常に「完了済み」を返すためチュートリアルは表示されない。
/// テスト既定やDI未設定時のフォールバックに使用する。
class NoopTutorialRepository implements TutorialRepository {
  const NoopTutorialRepository();

  @override
  Future<bool> isCompleted() async => true;

  @override
  Future<void> markCompleted() async {}

  @override
  Future<void> reset() async {}
}
