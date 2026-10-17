import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/about/domain/about_info.dart';

/// pubspec.yaml の version と kAboutInfo.version の同期試練。
void main() {
  test('pubspec.yaml のバージョンと kAboutInfo.version が一致する', () {
    final source = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$', multiLine: true)
            .firstMatch(source);
    expect(match, isNotNull, reason: 'pubspec.yaml に version 行が無い');
    expect(kAboutInfo.version, match!.group(1));
  });
}
