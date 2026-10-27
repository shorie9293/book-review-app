import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/features/about/domain/about_info.dart';

void main() {
  AboutInfo info({
    String appName = '読書レビュー',
    String version = '1.0.27',
    String contactEmail = 'test@example.com',
    String privacyPolicyUrl = 'https://example.com/privacy',
    String tagline = 'タグライン',
  }) =>
      AboutInfo(
        appName: appName,
        version: version,
        contactEmail: contactEmail,
        privacyPolicyUrl: privacyPolicyUrl,
        tagline: tagline,
      );

  group('AboutInfo バリデーション', () {
    test('appName の空文字は ArgumentError', () {
      expect(() => info(appName: ''), throwsArgumentError);
    });

    test('version の空文字は ArgumentError', () {
      expect(() => info(version: ''), throwsArgumentError);
    });

    test('contactEmail の空文字は ArgumentError', () {
      expect(() => info(contactEmail: ''), throwsArgumentError);
    });

    test('privacyPolicyUrl の空文字は ArgumentError', () {
      expect(() => info(privacyPolicyUrl: ''), throwsArgumentError);
    });

    test('tagline の空文字は ArgumentError', () {
      expect(() => info(tagline: ''), throwsArgumentError);
    });

    test('全項目が空文字でなければ生成できる', () {
      expect(info(), isA<AboutInfo>());
    });
  });

  group('kAboutInfo 既定値', () {
    test('既定値が試練の期待と一致する', () {
      expect(kAboutInfo.appName, '読書レビュー');
      expect(kAboutInfo.contactEmail, 'horie.shunta@gmail.com');
      expect(kAboutInfo.privacyPolicyUrl, 'https://www.yoppala.in/privacy');
      expect(kAboutInfo.version, '1.0.37');
      expect(kAboutInfo.tagline, isNotEmpty);
    });
  });
}
