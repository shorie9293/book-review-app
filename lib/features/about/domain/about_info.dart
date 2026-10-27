/// 「アプリについて」画面の表示情報。
///
/// 空文字は禁止（非constコンストラクタ本体で [ArgumentError]）。
/// 既定値は公開コンストラクタを経由しない私的なconstコンストラクタで
/// 定数化する（検証済みの値のみを許す）。
class AboutInfo {
  AboutInfo({
    required this.appName,
    required this.version,
    required this.contactEmail,
    required this.privacyPolicyUrl,
    required this.tagline,
  }) {
    _validate('appName', appName);
    _validate('version', version);
    _validate('contactEmail', contactEmail);
    _validate('privacyPolicyUrl', privacyPolicyUrl);
    _validate('tagline', tagline);
  }

  /// 検証済みの値のみで構成する既定インスタンス用の私的constコンストラクタ。
  const AboutInfo._({
    required this.appName,
    required this.version,
    required this.contactEmail,
    required this.privacyPolicyUrl,
    required this.tagline,
  });

  final String appName;
  final String version;
  final String contactEmail;
  final String privacyPolicyUrl;
  final String tagline;

  static void _validate(String name, String value) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, name, '空文字は許可されていません');
    }
  }
}

/// 既定の「アプリについて」情報。
const kAboutInfo = AboutInfo._(
  appName: '読書レビュー',
  version: '1.0.36',
  contactEmail: 'horie.shunta@gmail.com',
  privacyPolicyUrl: 'https://www.yoppala.in/privacy',
  tagline: '読書の記録とレビューで、学びを明日の力に。',
);
