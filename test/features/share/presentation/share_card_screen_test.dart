import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/testing/app_keys.dart';
import 'package:book_review_app/features/share/domain/share_card_data.dart';
import 'package:book_review_app/features/share/domain/share_card_service.dart';
import 'package:book_review_app/features/share/presentation/share_card_capture.dart';
import 'package:book_review_app/features/share/presentation/share_card_exporter.dart';
import 'package:book_review_app/features/share/presentation/share_card_screen.dart';

class _FakeExporter implements ShareCardExporter {
  final List<({Uint8List? image, String text})> calls = [];

  @override
  Future<bool> share({Uint8List? image, required String text}) async {
    calls.add((image: image, text: text));
    return true;
  }
}

class _FakeCapture implements ShareCardCapture {
  final Uint8List? bytes;
  int calls = 0;
  _FakeCapture(this.bytes);

  @override
  Future<Uint8List?> capture(GlobalKey boundaryKey) async {
    calls++;
    return bytes;
  }
}

ShareCardData data({
  ShareCardReview? favoriteReview,
  DateTime? generatedAt,
}) {
  return ShareCardData(
    completedCount: 3,
    unreadCount: 2,
    totalMinutes: 90,
    activeDays: 5,
    favoriteReview: favoriteReview,
    generatedAt: generatedAt ?? DateTime(2026, 3, 5),
  );
}

Future<void> pumpScreen(
  WidgetTester tester, {
  required ShareCardData dataOverride,
  ShareCardCapture? capture,
  ShareCardExporter? exporter,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ShareCardScreen(
        dataOverride: dataOverride,
        capture: capture,
        exporter: exporter,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ShareCardScreen', () {
    testWidgets('dataOverrideでプレビューのラベルとfavorite行を表示する',
        (tester) async {
      final exporter = _FakeExporter();
      await pumpScreen(
        tester,
        dataOverride: data(
          favoriteReview: ShareCardReview(
            bookTitle: 'こころ',
            rating: 5,
            excerpt: '人間は薄弱なものである',
          ),
        ),
        exporter: exporter,
      );
      expect(find.byKey(AppKeys.shareCardPreview), findsOneWidget);
      expect(find.text('📚 読書の歩み'), findsOneWidget);
      expect(find.text('読了 3冊'), findsOneWidget);
      expect(find.text('積読 2冊'), findsOneWidget);
      expect(find.text('読書時間: 1時間30分'), findsOneWidget);
      expect(find.text('⭐⭐⭐⭐⭐'), findsOneWidget);
      expect(find.textContaining('人間は薄弱'), findsOneWidget);
      expect(find.textContaining('こころ'), findsOneWidget);
      expect(find.text('2026/03/05'), findsOneWidget);
      expect(find.byKey(AppKeys.shareCardTextShareButton), findsOneWidget);
    });

    testWidgets('favoriteReviewがnullならfavorite行を表示しない', (tester) async {
      await pumpScreen(tester, dataOverride: data());
      expect(find.byKey(AppKeys.shareCardPreview), findsOneWidget);
      expect(find.text('読了 3冊'), findsOneWidget);
      expect(find.textContaining('こころ'), findsNothing);
      expect(find.textContaining('⭐'), findsNothing);
      expect(find.text('読書時間: 1時間30分'), findsOneWidget);
    });

    testWidgets('テキスト共有がexporterへ到達しshareText内容と一致する', (tester) async {
      final exporter = _FakeExporter();
      final d = data(
        favoriteReview: ShareCardReview(
          bookTitle: 'こころ',
          rating: 4,
          excerpt: '引用',
        ),
      );
      await pumpScreen(tester, dataOverride: d, exporter: exporter);
      await tester.tap(find.byKey(AppKeys.shareCardTextShareButton));
      await tester.pump();
      expect(exporter.calls, hasLength(1));
      expect(exporter.calls.single.image, isNull);
      expect(exporter.calls.single.text, ShareCardService.shareText(d));
    });

    testWidgets('画像共有: capture非null返却でexporterへ画像とテキストが到達する',
        (tester) async {
      final exporter = _FakeExporter();
      final capture =
          _FakeCapture(Uint8List.fromList([1, 2, 3]));
      final d = data();
      await pumpScreen(
        tester,
        dataOverride: d,
        capture: capture,
        exporter: exporter,
      );
      await tester.tap(find.byKey(AppKeys.shareCardImageShareButton));
      await tester.pump();
      expect(capture.calls, 1);
      expect(exporter.calls, hasLength(1));
      expect(exporter.calls.single.image, isNotNull);
      expect(
        exporter.calls.single.text,
        ShareCardService.shareText(d),
      );
    });

    testWidgets('画像共有: captureがnull返却でもexporterへtextのみで到達する',
        (tester) async {
      final exporter = _FakeExporter();
      final capture = _FakeCapture(null);
      await pumpScreen(
        tester,
        dataOverride: data(),
        capture: capture,
        exporter: exporter,
      );
      await tester.tap(find.byKey(AppKeys.shareCardImageShareButton));
      await tester.pump();
      expect(capture.calls, 1);
      expect(exporter.calls, hasLength(1));
      expect(exporter.calls.single.image, isNull);
    });

    testWidgets('captureがnullなら画像共有ボタンがdisabled', (tester) async {
      await pumpScreen(tester, dataOverride: data());
      final button = tester.widget<ElevatedButton>(
        find.byKey(AppKeys.shareCardImageShareButton),
      );
      expect(button.onPressed, isNull);
      final textButton = tester.widget<ElevatedButton>(
        find.byKey(AppKeys.shareCardTextShareButton),
      );
      expect(textButton.onPressed, isNotNull);
    });

    testWidgets('AppKeysを全プレビュー要素に撃てる', (tester) async {
      await pumpScreen(
        tester,
        dataOverride: data(
          favoriteReview: ShareCardReview(
            bookTitle: '無題',
            rating: 3,
            excerpt: '抜粋',
          ),
        ),
      );
      expect(find.byKey(AppKeys.shareCardScreen), findsOneWidget);
      expect(find.byKey(AppKeys.shareCardPreview), findsOneWidget);
    });
  });
}
