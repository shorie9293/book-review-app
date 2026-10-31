import 'package:flutter/material.dart';

import 'package:book_review_app/core/crash/crash_log_service.dart';

/// 画面を「未捕捉例外の受け皿」で包む境界。
///
/// [ErrorWidget.builder] を差し替え、子孫の build 中に投げられた例外を
/// 記録した上で、日本語の復帰 UI（再読み込み）へ差し替える。
/// 既存の [ErrorWidget.builder] は dispose で元に戻す。
///
/// MaterialApp の外でも壊れないよう、Theme / Directionality に依存しない。
class ErrorBoundary extends StatefulWidget {
  /// 保護対象。
  final Widget child;

  /// 記録役（未指定なら既定の端末内ログ）。
  final CrashLogger? logger;

  /// 復帰 UI のカスタマイズ（未指定なら既定 UI）。
  final Widget Function(BuildContext context, VoidCallback reload)?
      fallbackBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.logger,
    this.fallbackBuilder,
  });

  /// 復帰 UI の目印。
  static const Key fallbackKey = Key('crash_boundary_fallback');

  /// 復帰 UI の文言。
  static const Key messageKey = Key('crash_boundary_message');

  /// 再読み込みボタン。
  static const Key reloadKey = Key('crash_boundary_reload');

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Widget Function(FlutterErrorDetails)? _originalBuilder;
  late Widget Function(FlutterErrorDetails) _boundedBuilder;
  CrashLogger? _logger;

  /// 再読み込みの世代。増やすと子を付け替えて再構築させる。
  int _generation = 0;

  /// 直前に記録した例外（同一例外の多重記録を防ぐ）。
  Object? _lastRecorded;

  @override
  void initState() {
    super.initState();
    _logger = widget.logger;
    _originalBuilder = ErrorWidget.builder;
    _boundedBuilder = _buildFallbackFor;
    ErrorWidget.builder = _boundedBuilder;
  }

  @override
  void didUpdateWidget(ErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logger != oldWidget.logger) _logger = widget.logger;
  }

  @override
  void dispose() {
    if (identical(ErrorWidget.builder, _boundedBuilder)) {
      ErrorWidget.builder =
          _originalBuilder ?? (details) => ErrorWidget(details.exception);
    }
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _generation++);
  }

  Widget _buildFallbackFor(FlutterErrorDetails details) {
    if (!identical(_lastRecorded, details.exception)) {
      _lastRecorded = details.exception;
      final logger = _logger ?? defaultCrashLogger();
      logger.record(details.exception, details.stack, kind: 'widget');
    }
    final custom = widget.fallbackBuilder;
    if (custom != null) {
      return Builder(builder: (context) => custom(context, _reload));
    }
    return _CrashFallback(onReload: _reload);
  }

  @override
  Widget build(BuildContext context) {
    // 世代を key に載せ、再読み込みで子孫を作り直す。
    return KeyedSubtree(
      key: ValueKey<int>(_generation),
      child: widget.child,
    );
  }
}

/// 既定の復帰 UI（Material 非依存・Semantics 付き）。
class _CrashFallback extends StatelessWidget {
  final VoidCallback onReload;

  const _CrashFallback({required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Semantics(
        label: '表示中に問題が発生しました。再読み込みできます',
        container: true,
        child: Material(
          key: ErrorBoundary.fallbackKey,
          color: const Color(0xFFFFFBF5),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.report_problem_outlined,
                    size: 40,
                    color: Color(0xFF9A3412),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '表示中に問題が発生しました',
                    key: ErrorBoundary.messageKey,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3F2A17),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ご迷惑をおかけしました。再読み込みしてください。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF3F2A17)),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    key: ErrorBoundary.reloadKey,
                    onPressed: onReload,
                    child: const Text('再読み込み'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
