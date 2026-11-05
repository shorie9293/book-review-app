import 'package:book_review_app/core/infrastructure/lock_recovery_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('確認語は「初期化」', () {
    expect(LockRecoveryPolicy.confirmationPhrase, '初期化');
  });

  test('確認語は完全一致のみ有効（前後空白は許容）', () {
    expect(LockRecoveryPolicy.isConfirmationValid('初期化'), isTrue);
    expect(LockRecoveryPolicy.isConfirmationValid('  初期化\n'), isTrue);
    expect(LockRecoveryPolicy.isConfirmationValid('初期'), isFalse);
    expect(LockRecoveryPolicy.isConfirmationValid('しょきか'), isFalse);
    expect(LockRecoveryPolicy.isConfirmationValid(''), isFalse);
  });

  test('ロック中のときだけ回復できる', () {
    expect(LockRecoveryPolicy.canRecover(enabled: true), isTrue);
    expect(LockRecoveryPolicy.canRecover(enabled: false), isFalse);
  });

  test('警告文はデータ初期化と非可逆性を明示する', () {
    expect(LockRecoveryPolicy.warningTitle, isNotEmpty);
    expect(LockRecoveryPolicy.warningBody, contains('初期化'));
    expect(LockRecoveryPolicy.warningBody, contains('元に戻せません'));
  });
}
