import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_review_app/core/theme/app_theme.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:book_review_app/screens/main_screen.dart';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // ━━━ Firebase 運用監視基盤（Crashlytics クラッシュ検知 + Analytics KPI計測）━━━
  try {
    await Firebase.initializeApp();
    // Analytics: セッション開始を記録し DAU/定着率のKPI計測を有効化
    FirebaseAnalytics.instance.logAppOpen();
    debugPrint('[main] ✅ Firebase 初期化完了');
  } catch (e) {
    // テスト環境や Firebase 未設定時はアプリ起動を妨げず継続する
    debugPrint('[main] ⚠️ Firebase初期化失敗（アプリは継続）: $e');
  }

  // クラッシュ検知: Flutterフレームワーク内の致命的エラーを Crashlytics へ送信
  FlutterError.onError = (FlutterErrorDetails details) {
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {
      // Firebase 未初期化（テスト環境等）はスキップ
    }
    FlutterError.presentError(details);
  };
  // ゾーン外の非同期エラー（Platformレベル）
  PlatformDispatcher.instance.onError = (error, stack) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      // Firebase 未初期化（テスト環境等）はスキップ
    }
    return true;
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'book-review-app',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const ErrorBoundary(child: MainScreen()),
    );
  }
}
