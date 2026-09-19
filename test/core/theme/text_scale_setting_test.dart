import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/theme/text_scale_setting.dart';

void main() {
  group('TextScaleSetting', () {
    test('presets are 小/通常/大 with 0.9/1.0/1.25', () {
      expect(TextScaleSetting.presets.length, 3);
      expect(TextScaleSetting.presets[0].label, '小');
      expect(TextScaleSetting.presets[0].scale, 0.9);
      expect(TextScaleSetting.presets[1].label, '通常');
      expect(TextScaleSetting.presets[1].scale, 1.0);
      expect(TextScaleSetting.presets[2].label, '大');
      expect(TextScaleSetting.presets[2].scale, 1.25);
    });

    test('isAllowed accepts the 3 presets', () {
      expect(TextScaleSetting.isAllowed(0.9), isTrue);
      expect(TextScaleSetting.isAllowed(1.0), isTrue);
      expect(TextScaleSetting.isAllowed(1.25), isTrue);
    });

    test('isAllowed rejects other values', () {
      expect(TextScaleSetting.isAllowed(0.5), isFalse);
      expect(TextScaleSetting.isAllowed(1.1), isFalse);
      expect(TextScaleSetting.isAllowed(2.0), isFalse);
      expect(TextScaleSetting.isAllowed(0.0), isFalse);
      expect(TextScaleSetting.isAllowed(-1.0), isFalse);
    });

    test('isAllowed tolerates floating point error (<0.001)', () {
      expect(TextScaleSetting.isAllowed(0.9 + 1e-9), isTrue);
      expect(TextScaleSetting.isAllowed(1.25 - 1e-9), isTrue);
      expect(TextScaleSetting.isAllowed(0.9 + 0.001), isFalse);
    });

    test('fromScale returns preset for known scale', () {
      expect(TextScaleSetting.fromScale(0.9)?.label, '小');
      expect(TextScaleSetting.fromScale(1.0)?.label, '通常');
      expect(TextScaleSetting.fromScale(1.25)?.label, '大');
    });

    test('fromScale returns null for null or unknown scale', () {
      expect(TextScaleSetting.fromScale(null), isNull);
      expect(TextScaleSetting.fromScale(0.7), isNull);
    });

    test('normalized maps known scales to themselves', () {
      expect(TextScaleSetting.normalized(0.9), 0.9);
      expect(TextScaleSetting.normalized(1.0), 1.0);
      expect(TextScaleSetting.normalized(1.25), 1.25);
    });

    test('normalized defaults to 1.0 for null or unknown', () {
      expect(TextScaleSetting.normalized(null), 1.0);
      expect(TextScaleSetting.normalized(3.3), 1.0);
    });
  });
}
