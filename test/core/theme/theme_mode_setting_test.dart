import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/theme/theme_mode_setting.dart';

void main() {
  group('ThemeModeSetting.fromStorageKey', () {
    test('null returns system', () {
      expect(ThemeModeSetting.fromStorageKey(null), ThemeModeSetting.system);
    });

    test('unknown key returns system', () {
      expect(ThemeModeSetting.fromStorageKey(''), ThemeModeSetting.system);
      expect(
        ThemeModeSetting.fromStorageKey('unknown'),
        ThemeModeSetting.system,
      );
    });

    test('valid keys return corresponding modes', () {
      expect(ThemeModeSetting.fromStorageKey('light'), ThemeModeSetting.light);
      expect(ThemeModeSetting.fromStorageKey('dark'), ThemeModeSetting.dark);
      expect(
        ThemeModeSetting.fromStorageKey('system'),
        ThemeModeSetting.system,
      );
    });
  });

  group('ThemeModeSetting.next', () {
    test('cycles light → dark → system → light', () {
      expect(ThemeModeSetting.light.next, ThemeModeSetting.dark);
      expect(ThemeModeSetting.dark.next, ThemeModeSetting.system);
      expect(ThemeModeSetting.system.next, ThemeModeSetting.light);
    });

    test('three applications return to origin', () {
      var mode = ThemeModeSetting.light;
      final origin = mode;
      for (var i = 0; i < 3; i++) {
        mode = mode.next;
      }
      expect(mode, origin);
    });
  });

  group('ThemeModeSetting.toThemeMode', () {
    test('maps each value', () {
      expect(ThemeModeSetting.light.toThemeMode(), ThemeMode.light);
      expect(ThemeModeSetting.dark.toThemeMode(), ThemeMode.dark);
      expect(ThemeModeSetting.system.toThemeMode(), ThemeMode.system);
    });
  });

  group('ThemeModeSetting labels / storageKeys / icons', () {
    test('labels', () {
      expect(ThemeModeSetting.light.label, 'ライト');
      expect(ThemeModeSetting.dark.label, 'ダーク');
      expect(ThemeModeSetting.system.label, 'システム');
    });

    test('storageKeys', () {
      expect(ThemeModeSetting.light.storageKey, 'light');
      expect(ThemeModeSetting.dark.storageKey, 'dark');
      expect(ThemeModeSetting.system.storageKey, 'system');
    });

    test('icons are distinct', () {
      final icons = ThemeModeSetting.values.map((m) => m.icon).toSet();
      expect(icons.length, ThemeModeSetting.values.length);
    });
  });
}