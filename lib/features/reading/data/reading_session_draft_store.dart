/// 走行中セッションの下書き保存層。
///
/// 下書きは「計測が消えないための最後の砦」ゆえ、I/O 失敗で本編を止めない。
/// どの実装も read / write / clear で例外を投げない契約とする。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:book_review_app/core/logging/app_logger.dart';
import 'package:book_review_app/features/reading/domain/reading_session_draft.dart';

/// 走行中セッションの下書きを読み書きする抽象。
abstract class ReadingSessionDraftStore {
  /// 下書きを読む（無い・壊れている場合は null）。throw しない。
  Future<ReadingSessionDraft?> read();

  /// 下書きを書く。throw しない。
  Future<void> write(ReadingSessionDraft draft);

  /// 下書きを消す。throw しない。
  Future<void> clear();
}

/// 保存キー（形式変更時は末尾の版を上げる）。
const String readingSessionDraftKey = 'reading_session_draft_v1';

/// SharedPreferences による本番実装。
class SharedPreferencesReadingSessionDraftStore
    implements ReadingSessionDraftStore {
  SharedPreferencesReadingSessionDraftStore({
    Future<SharedPreferences> Function()? opener,
  }) : _opener = opener ?? SharedPreferences.getInstance;

  /// 保存先を開く関数（試練で I/O 失敗を注入するための差し替え口）。
  final Future<SharedPreferences> Function() _opener;

  Future<SharedPreferences?> _prefs(String operation) async {
    try {
      return await _opener();
    } catch (error, stackTrace) {
      // 失敗は黙殺せず警告を1回だけ残す（本編は止めない）。
      appLog.warn('読書セッション下書きの$operationに失敗しました', error, stackTrace);
      return null;
    }
  }

  @override
  Future<ReadingSessionDraft?> read() async {
    final prefs = await _prefs('読み込み');
    if (prefs == null) return null;
    try {
      final raw = prefs.getString(readingSessionDraftKey);
      if (raw == null || raw.isEmpty) return null;
      return ReadingSessionDraft.tryFromJson(json.decode(raw));
    } catch (error, stackTrace) {
      // 壊れた下書きは捨てる（復帰させないだけ・落とさない）。
      appLog.warn('読書セッション下書きの解析に失敗しました', error, stackTrace);
      return null;
    }
  }

  @override
  Future<void> write(ReadingSessionDraft draft) async {
    final prefs = await _prefs('保存');
    if (prefs == null) return;
    try {
      await prefs.setString(
        readingSessionDraftKey,
        json.encode(draft.toJson()),
      );
    } catch (error, stackTrace) {
      appLog.warn('読書セッション下書きの保存に失敗しました', error, stackTrace);
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs('削除');
    if (prefs == null) return;
    try {
      await prefs.remove(readingSessionDraftKey);
    } catch (error, stackTrace) {
      appLog.warn('読書セッション下書きの削除に失敗しました', error, stackTrace);
    }
  }
}

/// 試練・一時利用向けのメモリ実装。
class InMemoryReadingSessionDraftStore implements ReadingSessionDraftStore {
  InMemoryReadingSessionDraftStore({String? raw}) : _raw = raw;

  /// 保存されている生 JSON（検証用）。
  String? _raw;

  /// 保存されている生 JSON（検証用の読み取り専用ビュー）。
  String? get raw => _raw;

  /// write 回数（保存が呼ばれたことの検証用）。
  int writeCount = 0;

  /// clear 回数（保存成功後に消えたことの検証用）。
  int clearCount = 0;

  @override
  Future<ReadingSessionDraft?> read() async {
    final raw = _raw;
    if (raw == null || raw.isEmpty) return null;
    try {
      return ReadingSessionDraft.tryFromJson(json.decode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(ReadingSessionDraft draft) async {
    writeCount++;
    _raw = json.encode(draft.toJson());
  }

  @override
  Future<void> clear() async {
    clearCount++;
    _raw = null;
  }
}
