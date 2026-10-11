import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/share/presentation/share_card_capture.dart';
import 'package:book_review_app/features/share/presentation/share_card_exporter.dart';
import 'package:book_review_app/features/share/presentation/share_card_screen.dart';
import 'package:book_review_app/features/stats/presentation/stats_screen.dart';
import 'package:book_review_app/features/stats/presentation/viewmodel/stats_view_model.dart';

class _WiringSource implements StatsDataSource {
  @override
  Future<List<Book>> getBooks() async => [];
  @override
  Future<List<Review>> getAllReviews() async => [];
}

class _FakeExporter implements ShareCardExporter {
  int calls = 0;
  @override
  Future<bool> share({Uint8List? image, required String text}) async {
    calls++;
    return true;
  }
}

class _FakeCapture implements ShareCardCapture {
  int calls = 0;
  @override
  Future<Uint8List?> capture(GlobalKey boundaryKey) async {
    calls++;
    return null;
  }
}

void main() {
  group('StatsScreen → ShareCardScreen wiring', () {
    testWidgets('statsShareCardEntryタップでShareCardScreenへ遷移しプレビュー表示する',
        (tester) async {
      final exporter = _FakeExporter();
      final capture = _FakeCapture();
      await tester.pumpWidget(
        MaterialApp(
          home: StatsScreen(
            dataSource: _WiringSource(),
            capture: capture,
            exporter: exporter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.statsShareCardEntry), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.statsShareCardEntry));
      await tester.pumpAndSettle();

      expect(find.byType(ShareCardScreen), findsOneWidget);
      expect(find.text('読書シェアカード'), findsOneWidget);
      expect(find.byKey(AppKeys.shareCardPreview), findsOneWidget);
    });

    testWidgets('既存の統計画面アクションが壊れていない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: StatsScreen(dataSource: _WiringSource())),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.finishForecastOpenButton), findsOneWidget);
      expect(find.byKey(AppKeys.readingTrendEntry), findsOneWidget);
      expect(find.byKey(AppKeys.statsShareCardEntry), findsOneWidget);
    });
  });
}
