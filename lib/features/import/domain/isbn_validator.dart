/// ISBN の正規化と検査を行う純粋ユーティリティ。
///
/// 入力のゆれ（ハイフン・空白・全角数字・小文字 x のチェックディジット）を
/// 吸収したうえで、ISBN-10 / ISBN-13 のチェックディジットを検証する。
/// 副作用を持たず、単体で試練可能。
class IsbnValidator {
  const IsbnValidator._();

  /// 正規化後に許容される数字桁数（ISBN-10 / ISBN-13 のみ対応）。
  static const int isbn10Length = 10;
  static const int isbn13Length = 13;

  /// 入力を正規化する。
  ///
  /// 半角/全角の数字のみを残し、ISBN-10 のチェックディジット `X`/`x` は
  /// `X` に揃える。ハイフン・空白・その他の記号は除去される。
  /// ISBN として解釈不能な文字（数字でも X でもない英字・記号）は除去せず、
  /// [isValid] 側の判定で不正として扱うためここでは捨てるだけにする。
  static String normalize(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.trim().runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        buffer.writeCharCode(rune); // 0-9
      } else if (rune >= 0xFF10 && rune <= 0xFF19) {
        buffer.writeCharCode(rune - 0xFF10 + 0x30); // 全角数字
      } else if (rune == 0x58 || rune == 0x78) {
        buffer.write('X'); // チェックディジットの X / x
      }
    }
    return buffer.toString();
  }

  /// ISBN-10 または ISBN-13 として妥当か（チェックディジットを含めて検証）。
  ///
  /// 数字・ハイフン・空白・X 以外の文字を含む入力は、正規化で文字が落ちて
  /// 偶然妥当な桁数になることを防ぐため不正とする。
  static bool isValid(String raw) {
    if (raw.isEmpty) return false;
    if (!_onlyAllowedChars(raw)) return false;
    final normalized = normalize(raw);
    if (normalized.length == isbn10Length) return _isValidIsbn10(normalized);
    if (normalized.length == isbn13Length) return _isValidIsbn13(normalized);
    return false;
  }

  /// ハイフン・空白・数字・X 以外を含まないか。
  static bool _onlyAllowedChars(String raw) {
    for (final rune in raw.trim().runes) {
      final isHalfWidthDigit = rune >= 0x30 && rune <= 0x39;
      final isFullWidthDigit = rune >= 0xFF10 && rune <= 0xFF19;
      final isHyphen = rune == 0x2D || rune == 0xFF0D || rune == 0x2010 || rune == 0x2013 || rune == 0x2015;
      final isSpace = rune == 0x20 || rune == 0x09 || rune == 0x3000;
      final isX = rune == 0x58 || rune == 0x78;
      if (!isHalfWidthDigit && !isFullWidthDigit && !isHyphen && !isSpace && !isX) {
        return false;
      }
    }
    return true;
  }

  static bool _isValidIsbn10(String value) {
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      final digit = value.codeUnitAt(i) - 0x30;
      if (digit < 0 || digit > 9) return false;
      sum += digit * (10 - i);
    }
    final last = value[9];
    final int check;
    if (last == 'X') {
      check = 10;
    } else {
      check = value.codeUnitAt(9) - 0x30;
      if (check < 0 || check > 9) return false;
    }
    sum += check;
    return sum % 11 == 0;
  }

  static bool _isValidIsbn13(String value) {
    var sum = 0;
    for (var i = 0; i < isbn13Length; i++) {
      final digit = value.codeUnitAt(i) - 0x30;
      if (digit < 0 || digit > 9) return false;
      sum += digit * (i.isEven ? 1 : 3);
    }
    return sum % 10 == 0;
  }
}
