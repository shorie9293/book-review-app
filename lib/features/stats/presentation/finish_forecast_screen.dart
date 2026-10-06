import 'package:flutter/material.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/stats/domain/reading_pace.dart';
import 'package:book_review_app/features/stats/presentation/viewmodel/finish_forecast_view_model.dart';

/// 読了予測画面。
///
/// 進行中（reading）書籍ごとのペースと読了見込み日をカードで俯瞰する。
/// テスト用に [forecastsOverride] を渡すとロードせずそれを表示する。
class FinishForecastScreen extends StatefulWidget {
  final FinishForecastDataSource? dataSource;
  final DateTime Function()? clock;

  /// テスト用オーバーライド。非 null ならロードをせずこれを表示する。
  final List<FinishForecast>? forecastsOverride;

  const FinishForecastScreen({
    super.key,
    this.dataSource,
    this.clock,
    this.forecastsOverride,
  });

  @override
  State<FinishForecastScreen> createState() => _FinishForecastScreenState();
}

class _FinishForecastScreenState extends State<FinishForecastScreen> {
  late FinishForecastViewModel _viewModel;
  FinishForecastDataSource? _source;

  @override
  void initState() {
    super.initState();
    _viewModel = FinishForecastViewModel(clock: widget.clock);
    _viewModel.addListener(_handleViewModelChange);
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.forecastsOverride != null) {
      _viewModel.forecasts = widget.forecastsOverride;
      return;
    }
    _source = widget.dataSource ?? HiveFinishForecastDataSource();
    await _viewModel.load(_source!);
  }

  void _handleViewModelChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelChange);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('screen_finish_forecast'),
      appBar: AppBar(title: const Text('読了予測')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final List<FinishForecast>? forecasts;
    final bool loading;
    if (widget.forecastsOverride != null) {
      forecasts = widget.forecastsOverride;
      loading = false;
    } else {
      forecasts = _viewModel.forecasts;
      loading = _viewModel.isLoading && forecasts == null;
    }

    if (loading) {
      return const Center(
        key: Key('finish_forecast_loading'),
        child: CircularProgressIndicator(),
      );
    }
    final list = forecasts ?? const <FinishForecast>[];
    if (list.isEmpty) {
      return const Center(
        key: Key('finish_forecast_empty'),
        child: Text('読書中の本がありません。'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: list.length,
      itemBuilder: (context, index) =>
          _ForecastCard(forecast: list[index]),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final FinishForecast forecast;

  const _ForecastCard({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final pageCount = forecast.pageCount;
    final progress = pageCount > 0
        ? (forecast.currentPage / pageCount).clamp(0.0, 1.0)
        : 0.0;
    return Card(
      key: AppKeys.finishForecastCard(forecast.bookId),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    forecast.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(forecast.status.label)),
              ],
            ),
            const SizedBox(height: 4),
            Text('現在 ${forecast.currentPage} / ${forecast.pageCount} ページ'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(forecast.summaryLabel),
          ],
        ),
      ),
    );
  }
}