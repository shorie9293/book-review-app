import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:book_review_app/features/lifecycle/domain/day_rollover_detector.dart';

/// アプリが前面復帰した時に、日付が跨いでいれば [onRollover] を1回だけ呼ぶ。
///
/// 判定は [DayRolloverDetector] に委ね、[AppLifecycleState.resumed] の時だけ
/// 観測する。paused / inactive / hidden / detached では何もしない。
class AppLifecycleRefresher extends StatefulWidget {
  /// 暦日の跨ぎ判定器（アプリ生存期間で共有する）。
  final DayRolloverDetector detector;

  /// 日付跨ぎ時に走らせる再読込（1回だけ・投げっぱなし）。
  final Future<void> Function() onRollover;

  /// 監視対象の子。
  final Widget child;

  /// 現在日時の供給元（試練の決定論化用）。未指定なら [DateTime.now]。
  final DateTime Function()? now;

  const AppLifecycleRefresher({
    super.key,
    required this.detector,
    required this.onRollover,
    required this.child,
    this.now,
  });

  @override
  State<AppLifecycleRefresher> createState() => _AppLifecycleRefresherState();
}

class _AppLifecycleRefresherState extends State<AppLifecycleRefresher>
    with WidgetsBindingObserver {
  /// 再入防止（onRollover の実行中は追加発火しない）。
  bool _rolloverInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _checkRollover();
  }

  void _checkRollover() {
    if (_rolloverInFlight) return;
    final now = widget.now?.call() ?? DateTime.now();
    final result = widget.detector.check(now);
    if (result != DayRolloverResult.rolledOver) return;
    _rolloverInFlight = true;
    // 通知は副次的な処理なので、失敗してもアプリを落とさない。
    unawaited(
      widget.onRollover().catchError((Object error, StackTrace stack) {
        debugPrint('day rollover refresh failed: $error');
      }).whenComplete(() {
        _rolloverInFlight = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
