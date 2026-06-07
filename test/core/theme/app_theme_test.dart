import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light theme has useMaterial3 enabled', () {
      final theme = AppTheme.light;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
    });

    test('dark theme has useMaterial3 enabled', () {
      final theme = AppTheme.dark;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
    });

    test('light and dark themes have different brightness', () {
      final lightTheme = AppTheme.light;
      final darkTheme = AppTheme.dark;
      expect(lightTheme.brightness, isNot(darkTheme.brightness));
    });
  });
}
