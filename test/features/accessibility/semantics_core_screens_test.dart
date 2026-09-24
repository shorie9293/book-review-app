// UX アクセシビリティ基盤 — コア画面（本棚・詳細・設定系）の Semantics 試練
//
// コード適応神書 原則③（Semantics体系）に基づき、主要操作可能要素が
// SemanticHelper の identifier と日本語ラベルで露出することを検証する。
// find.bySemanticsIdentifier は ADB uiautomator の content-desc に、
// getSemantics の label は TalkBack 等の読み上げに対応する。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/domain/repositories/repositories.dart';
import 'package:book_review_app/features/bookshelf/data/hive_book_repository.dart';
import 'package:book_review_app/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:book_review_app/screens/text_scale_settings_screen.dart';
import 'package:book_review_app/screens/theme_mode_settings_screen.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';

Widget _buildBookshelfApp(
  HiveBookRepository repository, {
  List<Book> initialBooks = const [],
  ReviewRepository? reviewRepository,
}) {
  return MaterialApp(
    home: BookshelfScreen(
      repository: repository,
      initialBooks: initialBooks,
      reviewRepository: reviewRepository,
    ),
  );
}

Widget _buildTextScaleApp(double initialScale) {
  return MaterialApp(
    home: TextScaleSettingsScreen(
      currentScale: initialScale,
      onScaleChanged: (_) {},
    ),
  );
}

Widget _buildThemeModeApp(ThemeModeSetting initialMode) {
  return MaterialApp(
    home: ThemeModeSettingsScreen(
      currentMode: initialMode,
      onModeChanged: (_) {},
    ),
  );
}

void main() {
  late Directory tempDir;
  late HiveBookRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_semantics_core_');
    Hive.init(tempDir.path);
    repository = HiveBookRepository();
    await repository.init();
  });

  tearDown(() async {
    await repository.clear();
    await repository.close();
    await Hive.deleteBoxFromDisk('books');
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('BookshelfScreen アクセシビリティ', () {
    testWidgets('AppBar の主要操作ボタンに identifier とラベルが付与される',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_buildBookshelfApp(repository));
      await tester.pump();

      expect(find.bySemanticsIdentifier('bookshelf_btn_isbn_search'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('bookshelf_btn_scan_barcode'),
          findsOneWidget);

      // 検索ボタンのラベルが読み上げ可能であること
      final searchBtn = find.bySemanticsIdentifier('bookshelf_btn_isbn_search');
      final semantics = tester.getSemantics(searchBtn);
      expect(semantics.label, contains('ISBNで書籍を検索'));
      handle.dispose();
    });

    testWidgets('蔵書タイルに書籍名入りの identifier とラベルが付与される',
        (tester) async {
      final handle = tester.ensureSemantics();
      final book = Book(
        id: 'sem-book-1',
        title: 'アクセシビリティ入門',
        author: '著者太郎',
        isbn: 'isbn-sem-1',
      );
      await tester.pumpWidget(
        _buildBookshelfApp(repository, initialBooks: [book]),
      );
      await tester.pump();

      final tile = find.bySemanticsIdentifier(
          'bookshelf_book_tile_sem-book-1');
      expect(tile, findsOneWidget);
      final semantics = tester.getSemantics(tile);
      expect(semantics.label, contains('書籍「アクセシビリティ入門」を開く'));
      handle.dispose();
    });
  });

  group('TextScaleSettingsScreen アクセシビリティ', () {
    testWidgets('3段階の選択肢に identifier とラベルが付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_buildTextScaleApp(1.0));
      await tester.pump();

      expect(
          find.bySemanticsIdentifier('text_scale_option_0_9'), findsOneWidget);
      expect(
          find.bySemanticsIdentifier('text_scale_option_1_0'), findsOneWidget);
      expect(
          find.bySemanticsIdentifier('text_scale_option_1_25'),
          findsOneWidget);

      final large = find.bySemanticsIdentifier('text_scale_option_1_25');
      final semantics = tester.getSemantics(large);
      expect(semantics.label, contains('文字サイズ: 大'));
      handle.dispose();
    });
  });

  group('ThemeModeSettingsScreen アクセシビリティ', () {
    testWidgets('3モードの選択肢に identifier とラベルが付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_buildThemeModeApp(ThemeModeSetting.system));
      await tester.pump();

      expect(find.bySemanticsIdentifier('theme_mode_option_light'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('theme_mode_option_dark'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('theme_mode_option_system'),
          findsOneWidget);

      final dark = find.bySemanticsIdentifier('theme_mode_option_dark');
      final semantics = tester.getSemantics(dark);
      expect(semantics.label, contains('テーマ: ダーク'));
      handle.dispose();
    });
  });
}
