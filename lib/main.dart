import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:book_review_app/core/theme/app_theme.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:book_review_app/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
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
