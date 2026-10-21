import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hapticTap', () {
    test('例外を投げない（チャネル未解決でも安全）', () {
      expect(hapticTap, returnsNormally);
    });

    test('連続呼び出しでも例外を投げない', () {
      expect(() {
        hapticTap();
        hapticTap();
      }, returnsNormally);
    });
  });
}
