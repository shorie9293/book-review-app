import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:book_review_app/features/reading/data/reading_session_draft_store.dart';
import 'package:book_review_app/features/reading/domain/reading_session_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final startedAt = DateTime.utc(2026, 10, 4, 3, 0);

  group('InMemoryReadingSessionDraftStore', () {
    test('write → read → clear が往復する', () async {
      final store = InMemoryReadingSessionDraftStore();

      expect(await store.read(), isNull);

      await store.write(ReadingSessionDraft(startedAt: startedAt));
      final restored = await store.read();
      expect(restored, isNotNull);
      expect(restored!.startedAt, startedAt);
      expect(store.writeCount, 1);

      await store.clear();
      expect(await store.read(), isNull);
      expect(store.clearCount, 1);
      expect(store.raw, isNull);
    });

    test('壊れた生 JSON を読んでも throw せず null', () async {
      final store = InMemoryReadingSessionDraftStore(raw: '{壊れている');
      expect(await store.read(), isNull);
    });

    test('型違いの JSON を読んでも throw せず null', () async {
      final store =
          InMemoryReadingSessionDraftStore(raw: json.encode([1, 2, 3]));
      expect(await store.read(), isNull);
    });
  });

  group('SharedPreferencesReadingSessionDraftStore', () {
    test('未保存なら null', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = SharedPreferencesReadingSessionDraftStore();

      expect(await store.read(), isNull);
    });

    test('write → read → clear が実キーで往復する', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = SharedPreferencesReadingSessionDraftStore();

      await store.write(ReadingSessionDraft(startedAt: startedAt));

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(readingSessionDraftKey);
      expect(raw, isNotNull);
      // 保存は UTC 瞬間（暦ではない）
      expect(raw as String, contains('Z'));

      final restored = await store.read();
      expect(restored, isNotNull);
      expect(restored!.startedAt, startedAt);

      await store.clear();
      expect(await store.read(), isNull);
      expect(prefs.getString(readingSessionDraftKey), isNull);
    });

    test('壊れた保存値は null（throw しない）', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        readingSessionDraftKey: 'これは JSON ではない',
      });
      final store = SharedPreferencesReadingSessionDraftStore();

      expect(await store.read(), isNull);
    });

    test('I/O 失敗でも read は null・write/clear は throw しない', () async {
      final store = SharedPreferencesReadingSessionDraftStore(
        opener: () async => throw StateError('保存先を開けない'),
      );

      expect(await store.read(), isNull);
      await store.write(ReadingSessionDraft(startedAt: startedAt));
      await store.clear();
    });
  });
}
