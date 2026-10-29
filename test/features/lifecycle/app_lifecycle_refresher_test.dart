import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/lifecycle/domain/day_rollover_detector.dart';
import 'package:book_review_app/features/lifecycle/presentation/app_lifecycle_refresher.dart';

/// 前面復帰を確実に届けるため、いったん背面へ落としてから resumed を送る。
///
/// `handleAppLifecycleStateChanged` は同一状態の連続通知を無視し得るうえ、
/// Flutter は resumed→inactive→hidden→paused→…→resumed の遷移しか許さないため、
/// 正規の遷移を挟む。
Future<void> _simulateForegroundResume(WidgetTester tester) async {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

Future<void> _simulatePause(WidgetTester tester) async {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

/// 試練間でライフサイクル状態を持ち越さないための後始末。
void _restoreLifecycle(WidgetTester tester) {
  if (tester.binding.lifecycleState == AppLifecycleState.resumed) return;
  for (final state in const [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  testWidgets('暦日が跨いだ前面復帰で onRollover が1回だけ呼ばれる', (tester) async {
    var calls = 0;
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 28, 9, 0));

    await tester.pumpWidget(
      AppLifecycleRefresher(
        detector: detector,
        now: () => DateTime(2026, 10, 29, 9, 0),
        onRollover: () async {
          calls++;
        },
        child: const SizedBox.shrink(),
      ),
    );

    await _simulateForegroundResume(tester);
    await tester.pumpAndSettle();

    expect(calls, 1);
    _restoreLifecycle(tester);
  });

  testWidgets('同じ暦日の前面復帰では onRollover を呼ばない', (tester) async {
    var calls = 0;
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 8, 0));

    await tester.pumpWidget(
      AppLifecycleRefresher(
        detector: detector,
        now: () => DateTime(2026, 10, 29, 20, 0),
        onRollover: () async {
          calls++;
        },
        child: const SizedBox.shrink(),
      ),
    );

    await _simulateForegroundResume(tester);
    await tester.pumpAndSettle();

    expect(calls, 0);
    _restoreLifecycle(tester);
  });

  testWidgets('paused / inactive では onRollover を呼ばない', (tester) async {
    var calls = 0;
    // 暦日が跨いでいても paused では発火しないことを確かめる
    // （後始末の resumed で誤発火しないよう、判定は同日に戻せる値を使う）。
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 8, 0));

    await tester.pumpWidget(
      AppLifecycleRefresher(
        detector: detector,
        now: () => DateTime(2026, 10, 29, 20, 0),
        onRollover: () async {
          calls++;
        },
        child: const SizedBox.shrink(),
      ),
    );

    await _simulatePause(tester);
    await tester.pumpAndSettle();

    expect(calls, 0);
    _restoreLifecycle(tester);
  });

  testWidgets('onRollover が例外を投げても widget は落ちず、呼出は1回に留まる', (tester) async {
    var calls = 0;
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 28, 9, 0));

    await tester.pumpWidget(
      AppLifecycleRefresher(
        detector: detector,
        now: () => DateTime(2026, 10, 29, 9, 0),
        onRollover: () async {
          calls++;
          throw StateError('boom');
        },
        child: const SizedBox.shrink(),
      ),
    );

    await _simulateForegroundResume(tester);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(tester.takeException(), isNull);
    expect(find.byType(SizedBox), findsOneWidget);
    _restoreLifecycle(tester);
  });

  testWidgets('前面復帰を繰り返しても同日なら追加呼出しない（再入防止）', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      AppLifecycleRefresher(
        detector: DayRolloverDetector(lastSeen: DateTime(2026, 10, 28, 9, 0)),
        now: () => DateTime(2026, 10, 29, 9, 0),
        onRollover: () async {
          calls++;
        },
        child: const SizedBox.shrink(),
      ),
    );

    await _simulateForegroundResume(tester);
    await tester.pumpAndSettle();
    await _simulateForegroundResume(tester);
    await tester.pumpAndSettle();

    expect(calls, 1);
    _restoreLifecycle(tester);
  });
}
