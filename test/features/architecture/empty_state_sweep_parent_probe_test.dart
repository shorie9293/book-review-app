// 親探針（イシコリドメ）: EmptyState 適用拡大（book-review-app）の独立検証。
//
// 眷属が置いた画面別試練とは別に、親が「部品の二分性」「合成（検索→0件→クリア）」
// 「旧 Key の保持」「ソース不変条件」を撃つ。実装の言い分ではなく実物を測るための探針。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/core/widgets/empty_state.dart';
import 'package:book_review_app/domain/models/book_loan.dart';
import 'package:book_review_app/domain/repositories/book_loan_repository.dart';
import 'package:book_review_app/features/loan/presentation/loan_management_screen.dart';
import 'package:book_review_app/features/reading/data/reading_session_repository.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:book_review_app/features/reading/presentation/reading_session_screen.dart';

class _EmptyLoanRepository implements BookLoanRepository {
  @override
  Future<List<BookLoan>> loadLoans() async => const [];

  @override
  Future<void> saveLoans(List<BookLoan> loans) async {}
}

class _OneLoanRepository implements BookLoanRepository {
  _OneLoanRepository(this.loan);

  final BookLoan loan;

  @override
  Future<List<BookLoan>> loadLoans() async => [loan];

  @override
  Future<void> saveLoans(List<BookLoan> loans) async {}
}

class _EmptySessionRepository implements ReadingSessionRepository {
  @override
  Future<List<ReadingSession>> loadAll() async => const [];

  @override
  Future<void> add(ReadingSession session) async {}

  @override
  Future<void> update(ReadingSession session) async {}

  @override
  Future<void> remove(String id) async {}
}

void main() {
  // 実時計に依存しない固定時刻（TZ=UTC/JST どちらでも同じ暦日）。
  final now = DateTime.utc(2026, 11, 17, 3).toLocal();

  group('P1: 部品の二分性（action を持つ spec だけがボタンを1つ描く）', () {
    testWidgets('action 無しの spec はボタンを描かない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              key: const ValueKey('p1_no_action'),
              spec: EmptyStateSpec(title: 'まだ何もありません'),
            ),
          ),
        ),
      );

      expect(find.text('まだ何もありません'), findsOneWidget);
      expect(find.byKey(EmptyStateView.actionButtonKey), findsNothing);
    });

    testWidgets('action 有りの spec はボタンを1つだけ描き、押下で発火する', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              key: const ValueKey('p1_with_action'),
              spec: EmptyStateSpec(
                title: 'まだ何もありません',
                actionLabel: '最初の一冊を追加',
                onAction: () => taps++,
              ),
            ),
          ),
        ),
      );

      // 一覧・画面に複数並んでも一意に掴めること（key が static で固定）。
      expect(find.byKey(EmptyStateView.actionButtonKey), findsOneWidget);
      expect(find.text('最初の一冊を追加'), findsOneWidget);

      await tester.tap(find.byKey(EmptyStateView.actionButtonKey));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('actionLabel 片方だけの spec は ArgumentError で弾かれる', (tester) async {
      expect(
        () => EmptyStateSpec(title: 'タイトル', actionLabel: 'だけ'),
        throwsArgumentError,
      );
      expect(
        () => EmptyStateSpec(title: 'タイトル', onAction: () {}),
        throwsArgumentError,
      );
      expect(() => EmptyStateSpec(title: '  '), throwsArgumentError);
    });
  });

  group('P2: 合成（貸出画面: 検索→0件→クリアで行が戻る）', () {
    BookLoan loan() => BookLoan(
          id: 'l1',
          bookId: 'b1',
          borrower: '田中',
          lentAt: now.subtract(const Duration(days: 3)),
          dueAt: now.add(const Duration(days: 7)),
        );

    testWidgets('検索中に0件なら「検索をクリア」が1つ出て、押すと一覧が戻る', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: LoanManagementScreen(
            repository: _OneLoanRepository(loan()),
            nowOverride: now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 検索前は行が出ている＝空状態ではない。
      expect(find.byKey(AppKeys.loanEmpty), findsNothing);

      await tester.enterText(find.byKey(AppKeys.loanSearchField), '存在しない借り手');
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.loanEmpty), findsOneWidget);
      expect(find.byKey(EmptyStateView.actionButtonKey), findsOneWidget);
      expect(find.text('検索をクリア'), findsOneWidget);

      await tester.tap(find.byKey(EmptyStateView.actionButtonKey));
      await tester.pumpAndSettle();

      // クリア後は空状態が消え、行が戻る（＝導線が実際に効いている）。
      expect(find.byKey(AppKeys.loanEmpty), findsNothing);
      expect(find.byKey(AppKeys.loanRow('l1')), findsOneWidget);
    });

    testWidgets('検索していない0件では行動ボタンを出さない（偽の導線を作らない）', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: LoanManagementScreen(
            repository: _EmptyLoanRepository(),
            nowOverride: now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.loanEmpty), findsOneWidget);
      expect(find.byKey(EmptyStateView.actionButtonKey), findsNothing);
    });
  });

  group('P3: 読書時間画面 0件時の二重 Key 保持（既存試練の掴み手を壊さない）', () {
    testWidgets('旧 Key(load_empty_view) と AppKeys.readingEmpty が同居し、失敗表示は出ない', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingSessionScreen(
            repository: _EmptySessionRepository(),
            now: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('load_empty_view')), findsOneWidget);
      expect(find.byKey(AppKeys.readingEmpty), findsOneWidget);
      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('まだ記録がありません'), findsOneWidget);
    });
  });

  group('P4: ソース不変条件（二重系統の残骸が無いこと）', () {
    test('lib/ と test/ に旧部品 LoadEmptyView の参照が残っていない', () {
      final roots = ['lib', 'test'];
      final hits = <String>[];
      for (final root in roots) {
        final dir = Directory(root);
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File) continue;
          if (!entity.path.endsWith('.dart')) continue;
          // この探針自身は「禁止語」を文字列として持つため走査対象から除く。
          if (entity.path.contains('empty_state_sweep_parent_probe')) continue;
          if (entity.readAsStringSync().contains('LoadEmptyView')) {
            hits.add(entity.path);
          }
        }
      }
      expect(hits, isEmpty, reason: '旧部品の参照が残存: $hits');
    });

    test('置換した9画面に EmptyStateView 呼出が実在する', () {
      const screens = [
        'lib/features/reading/presentation/reading_session_screen.dart',
        'lib/features/recommendation/presentation/recommendation_screen.dart',
        'lib/features/notes/presentation/favorite_notes_screen.dart',
        'lib/features/loan/presentation/loan_management_screen.dart',
        'lib/features/bookshelf/presentation/stagnant_books_screen.dart',
        'lib/features/duplicates/presentation/duplicate_books_screen.dart',
        'lib/features/stats/presentation/stats_screen.dart',
        'lib/features/import/presentation/import_history_screen.dart',
        'lib/features/bookshelf/presentation/bookshelf_screen.dart',
      ];
      for (final path in screens) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '画面が存在しない: $path');
        expect(
          file.readAsStringSync().contains('EmptyStateView('),
          isTrue,
          reason: '共通部品へ未置換: $path',
        );
      }
    });
  });
}
