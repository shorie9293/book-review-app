import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/widgets/empty_state.dart';

/// [EmptyStateSpec] / [EmptyStateView] の試練。
///
/// 不変条件は assert ではなく ArgumentError で守る（release でも壊れた
/// 空状態を作らせない）ため、ここでは例外型まで確かめる。
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  group('EmptyStateSpec', () {
    test('title だけで生成でき、説明と行動は未設定になる', () {
      final spec = EmptyStateSpec(title: 'まだ何もありません');

      expect(spec.title, 'まだ何もありません');
      expect(spec.description, isNull);
      expect(spec.actionLabel, isNull);
      expect(spec.onAction, isNull);
      expect(spec.hasAction, isFalse);
    });

    test('title が空文字なら ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('title が空白のみなら ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('actionLabel だけ指定すると ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: '見出し', actionLabel: '本を追加'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('onAction だけ指定すると ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: '見出し', onAction: () {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('actionLabel が空白のみなら ArgumentError', () {
      expect(
        () => EmptyStateSpec(
          title: '見出し',
          actionLabel: '  ',
          onAction: () {},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('actionLabel と onAction を揃えれば hasAction が true', () {
      final spec = EmptyStateSpec(
        title: '見出し',
        description: '説明',
        actionLabel: '本を追加',
        onAction: () {},
      );

      expect(spec.hasAction, isTrue);
      expect(spec.description, '説明');
    });
  });

  group('EmptyStateView', () {
    testWidgets('見出しと説明を表示し、Key で掴める', (tester) async {
      await pump(
        tester,
        EmptyStateView(
          key: const Key('empty_state_under_test'),
          spec: EmptyStateSpec(
            title: '📚 蔵書がありません',
            description: 'バーコードを読み取って追加しましょう。',
          ),
        ),
      );

      expect(find.byKey(const Key('empty_state_under_test')), findsOneWidget);
      expect(find.text('📚 蔵書がありません'), findsOneWidget);
      expect(find.text('バーコードを読み取って追加しましょう。'), findsOneWidget);
    });

    testWidgets('説明が null なら見出しだけを表示する', (tester) async {
      await pump(
        tester,
        EmptyStateView(
          key: const Key('empty_state_no_description'),
          spec: EmptyStateSpec(title: 'メモはまだありません'),
        ),
      );

      expect(find.text('メモはまだありません'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('行動が無ければボタンを描かない', (tester) async {
      await pump(
        tester,
        EmptyStateView(
          key: const Key('empty_state_no_action'),
          spec: EmptyStateSpec(title: 'まだ記録がありません'),
        ),
      );

      expect(find.byKey(EmptyStateView.actionButtonKey), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('行動があればボタンを描き、押すと1回だけ呼ばれる', (tester) async {
      var taps = 0;
      await pump(
        tester,
        EmptyStateView(
          key: const Key('empty_state_with_action'),
          spec: EmptyStateSpec(
            title: 'メモはまだありません',
            actionLabel: 'メモを書く',
            onAction: () => taps++,
          ),
        ),
      );

      expect(find.byKey(EmptyStateView.actionButtonKey), findsOneWidget);
      expect(find.text('メモを書く'), findsOneWidget);

      await tester.tap(find.byKey(EmptyStateView.actionButtonKey));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('アイコンは指定時のみ描く', (tester) async {
      await pump(
        tester,
        EmptyStateView(
          key: const Key('empty_state_icon'),
          icon: Icons.menu_book_outlined,
          spec: EmptyStateSpec(title: '見出し'),
        ),
      );
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);

      await pump(
        tester,
        EmptyStateView(
          key: const Key('empty_state_no_icon'),
          spec: EmptyStateSpec(title: '見出し'),
        ),
      );
      expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
    });

    testWidgets('行動ボタンに Semantics の testId が付く', (tester) async {
      // ensureSemantics の handle はテスト本体で dispose する
      // （addTearDown では end-of-test 検証に間に合わない）。
      final handle = tester.ensureSemantics();

      await pump(
        tester,
        EmptyStateView(
          key: const Key('empty_state_semantics'),
          spec: EmptyStateSpec(
            title: '見出し',
            actionLabel: '本を追加',
            onAction: () {},
          ),
        ),
      );

      // SemanticHelper.interactive が付けた testId とラベルを確かめる。
      final node = tester.getSemantics(
        find.bySemanticsIdentifier('empty_state_action'),
      );
      expect(node.label, '本を追加');

      handle.dispose();
    });
  });
}
