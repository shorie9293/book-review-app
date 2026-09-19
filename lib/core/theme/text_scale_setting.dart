/// 文字サイズ設定（3段階）の定義
class TextScaleSetting {
  final String label;
  final double scale;

  const TextScaleSetting._(this.label, this.scale);

  static const double smallScale = 0.9;
  static const double normalScale = 1.0;
  static const double largeScale = 1.25;

  /// 許可される3段階（小／通常／大）
  static const List<TextScaleSetting> presets = [
    TextScaleSetting._('小', smallScale),
    TextScaleSetting._('通常', normalScale),
    TextScaleSetting._('大', largeScale),
  ];

  /// 許可される倍率か（数値誤差を許容）
  static bool isAllowed(double scale) =>
      presets.any((p) => (p.scale - scale).abs() < 0.001);

  /// スケール値に対応する設定。未保存/不正値は null。
  static TextScaleSetting? fromScale(double? scale) {
    if (scale == null) return null;
    for (final p in presets) {
      if ((p.scale - scale).abs() < 0.001) return p;
    }
    return null;
  }

  /// 倍率から正規化したスケール値（未保存は1.0）
  static double normalized(double? scale) =>
      fromScale(scale)?.scale ?? normalScale;
}
