import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:book_review_app/core/infrastructure/app_lock_repository.dart';
import 'package:book_review_app/core/theme/reduce_motion_repository.dart';
import 'package:book_review_app/core/theme/reduce_motion_setting.dart';
import 'package:book_review_app/core/theme/text_scale_repository.dart';
import 'package:book_review_app/core/theme/text_scale_setting.dart';
import 'package:book_review_app/core/theme/theme_mode_repository.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/book_note_repository.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/backup/data/backup_repository.dart';
import 'package:book_review_app/features/backup/domain/backup_models.dart';
import 'package:book_review_app/features/backup/domain/backup_settings_spec.dart';
import 'package:book_review_app/features/tutorial/data/tutorial_repository.dart';

Book _book(String id) => Book(
      id: id,
      title: '本 $id',
      author: '著者',
      isbn: 'isbn-$id',
      addedAt: DateTime.utc(2026, 1, 1),
    );

Review _review(String id, String bookId) => Review(
      id: id,
      bookId: bookId,
      rating: 5,
      text: 'text',
      createdAt: DateTime.utc(2026, 2, 2),
    );

BookNote _note(String id, String bookId) => BookNote(
      id: id,
      bookId: bookId,
      content: 'メモ $id',
      createdAt: DateTime.utc(2026, 3, 3),
    );

/// テスト用の簡易 BookRepository
class _FakeBookRepository implements BookRepository {
  final Map<String, Book> store;
  _FakeBookRepository(List<Book> initial)
      : store = {for (final b in initial) b.id: b};

  @override
  Future<List<Book>> getBooks() async => store.values.toList();

  @override
  Future<Book?> getBookById(String id) async => store[id];

  @override
  Future<Book?> findByIsbn(String isbn) async => null;

  @override
  Future<void> addBook(Book book) async => store[book.id] = book;

  @override
  Future<void> updateBook(Book book) async => store[book.id] = book;

  @override
  Future<void> removeBook(String id) async => store.remove(id);
}

/// テスト用の簡易 ReviewRepository
class _FakeReviewRepository implements ReviewRepository {
  final Map<String, Review> store;
  _FakeReviewRepository(List<Review> initial)
      : store = {for (final r in initial) r.id: r};

  @override
  Future<List<Review>> getReviewsByBookId(String bookId) async =>
      store.values.where((r) => r.bookId == bookId).toList();

  @override
  Future<void> addReview(Review review) async => store[review.id] = review;

  @override
  Future<void> updateReview(Review review) async => store[review.id] = review;

  @override
  Future<void> deleteReview(String id) async => store.remove(id);
}

/// テスト用の簡易 BookNoteRepository
class _FakeNoteRepository implements BookNoteRepository {
  final Map<String, BookNote> store;
  _FakeNoteRepository(List<BookNote> initial)
      : store = {for (final n in initial) n.id: n};

  @override
  Future<List<BookNote>> getNotesByBookId(String bookId) async =>
      store.values.where((n) => n.bookId == bookId).toList();

  @override
  Future<List<BookNote>> getAllNotes() async => store.values.toList();

  @override
  Future<void> addNote(BookNote note) async => store[note.id] = note;

  @override
  Future<void> updateNote(BookNote note) async => store[note.id] = note;

  @override
  Future<void> deleteNote(String id) async => store.remove(id);

  @override
  Future<void> deleteNotesByBookId(String bookId) async =>
      store.removeWhere((_, n) => n.bookId == bookId);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('book_backup_settings_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  HiveBackupRepository buildRepo() => HiveBackupRepository(
        bookRepository: _FakeBookRepository([_book('b1')]),
        reviewRepository: _FakeReviewRepository([_review('r1', 'b1')]),
        noteRepository: _FakeNoteRepository([_note('n1', 'b1')]),
      );

  BackupBundle bundleWith(Map<String, Object?> settingsValues) => BackupBundle(
        exportedAt: DateTime.utc(2026, 11, 9),
        books: const [],
        reviews: const [],
        notes: const [],
        settings: BackupSettingsBundle(values: settingsValues),
      );

  group('HiveBackupRepository.collect と設定', () {
    test('実在キーの設定を許可リスト経由で載せる（app_lock は載せない）', () async {
      await const ThemeModeRepository().saveThemeMode(ThemeModeSetting.dark);
      await const TextScaleRepository().saveScale(TextScaleSetting.largeScale);
      await const ReduceMotionRepository().save(ReduceMotionSetting.on);
      await const HiveTutorialRepository().markCompleted();
      // 秘密（控えに載ってはならない）
      final settingsBox = await Hive.openBox<String>('settings');
      await settingsBox.put('app_lock.passcode_hash', 'v2:1:aa:bb');

      final bundle = await buildRepo().collect();

      expect(bundle.settings, isNotNull);
      expect(bundle.settings!.values, <String, Object?>{
        'book_review_theme_mode': 'dark',
        'book_review_text_scale': 1.25,
        'book_reduce_motion': 'on',
        'book_review_tutorial_completed': true,
      });
      expect(
        bundle.settings!.values.keys.any((k) => k.startsWith('app_lock.')),
        isFalse,
      );
      // 本体（蔵書・レビュー・メモ）は従来どおり
      expect(bundle.books.single.id, 'b1');
      expect(bundle.reviews.single.id, 'r1');
      expect(bundle.notes.single.id, 'n1');
    });

    test('設定が未保存なら settings は null（従来と同一の控え）', () async {
      final bundle = await buildRepo().collect();

      expect(bundle.settings, isNull);
      expect(bundle.toJson().containsKey('settings'), isFalse);
    });

    test('Hive 未初期化でも collect は throw しない（settings は null）', () async {
      await Hive.close();
      final bundle = await buildRepo().collect();

      expect(bundle.books.single.id, 'b1');
      expect(bundle.settings, isNull);
    });
  });

  group('HiveBackupRepository.restore の設定適用', () {
    test('往復でテーマ・文字サイズ・動き・チュートリアルが戻る', () async {
      await const ThemeModeRepository().saveThemeMode(ThemeModeSetting.dark);
      await const TextScaleRepository().saveScale(TextScaleSetting.largeScale);
      await const ReduceMotionRepository().save(ReduceMotionSetting.on);
      await const HiveTutorialRepository().markCompleted();
      final repo = buildRepo();
      final saved = await repo.collect();

      // すべて既定へ戻す（復元で元に戻ることを確かめる）
      await const ThemeModeRepository().saveThemeMode(ThemeModeSetting.light);
      await const TextScaleRepository().saveScale(TextScaleSetting.normalScale);
      await const ReduceMotionRepository().save(ReduceMotionSetting.system);
      await const HiveTutorialRepository().reset();

      await repo.restore(saved);

      expect(
        await const ThemeModeRepository().loadThemeMode(),
        ThemeModeSetting.dark,
      );
      expect(await const TextScaleRepository().loadScale(), 1.25);
      expect(
          await const ReduceMotionRepository().load(), ReduceMotionSetting.on);
      expect(await const HiveTutorialRepository().isCompleted(), isTrue);
    });

    test('includeSettings: false なら設定を触らない', () async {
      final saved = bundleWith(<String, Object?>{
        'book_review_theme_mode': 'dark',
        'book_review_text_scale': 1.25,
      });
      await const ThemeModeRepository().saveThemeMode(ThemeModeSetting.light);
      await const TextScaleRepository().saveScale(TextScaleSetting.normalScale);

      await buildRepo().restore(saved, includeSettings: false);

      expect(
        await const ThemeModeRepository().loadThemeMode(),
        ThemeModeSetting.light,
      );
      expect(await const TextScaleRepository().loadScale(), 1.0);
    });

    test('未知キーは無視し、型不一致は個別に握って他の設定は適用する', () async {
      final saved = bundleWith(<String, Object?>{
        'unknown_key': 1,
        'book_review_text_scale': 999.0, // 許可外の倍率
        'book_review_theme_mode': 123, // 型不一致
        'book_review_tutorial_completed': true,
      });
      await const ThemeModeRepository().saveThemeMode(ThemeModeSetting.light);

      final result = await buildRepo().restore(saved);

      expect(result.booksAdded, 0);
      expect(
        await const ThemeModeRepository().loadThemeMode(),
        ThemeModeSetting.light,
      );
      expect(await const TextScaleRepository().loadScale(), isNull);
      expect(await const HiveTutorialRepository().isCompleted(), isTrue);
    });

    test('控えに app_lock 系が混ざっていても適用しない', () async {
      final saved = bundleWith(<String, Object?>{
        'app_lock.enabled': true,
        'app_lock.passcode_hash': 'v2:1:aa:bb',
        'book_review_theme_mode': 'dark',
      });

      await buildRepo().restore(saved);

      const appLock = HiveAppLockRepository();
      expect(appLock.isEnabled(), isFalse);
      expect(appLock.getPasscodeHash(), isNull);
      expect(
        await const ThemeModeRepository().loadThemeMode(),
        ThemeModeSetting.dark,
      );
    });

    test('settings 無しの旧控えを復元しても設定は変わらない', () async {
      await const ThemeModeRepository().saveThemeMode(ThemeModeSetting.light);
      final legacy = BackupBundle(
        exportedAt: DateTime.utc(2026, 11, 9),
        books: const [],
        reviews: const [],
        notes: const [],
      );

      final result = await buildRepo().restore(legacy);

      expect(result.booksAdded, 0);
      expect(
        await const ThemeModeRepository().loadThemeMode(),
        ThemeModeSetting.light,
      );
    });
  });
}
