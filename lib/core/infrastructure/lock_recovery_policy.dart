/// パスコード忘却時の回復導線の掟（純粋ロジック・I/O なし）。
///
/// 回復は「破壊的」であるため、二段確認（警告 → 確認語入力）を必須とする。
class LockRecoveryPolicy {
  const LockRecoveryPolicy._();

  /// 入力すべき確認語。誤操作防止のため完全一致（前後空白のみ許容）。
  static const String confirmationPhrase = '初期化';

  /// 警告の見出し。
  static const String warningTitle = 'パスコードを忘れた場合';

  /// 警告本文（失われるものを明示する）。
  static const String warningBody =
      'ロックを解除するには、この端末の蔵書・レビュー・メモなどのデータを'
      'すべて初期化します。初期化したデータは元に戻せません。'
      '可能なら事前にバックアップを書き出しますが、失敗する場合もあります。';

  /// 回復を実行してよい状態か（ロック中のときだけ意味がある）。
  static bool canRecover({required bool enabled}) => enabled;

  /// 確認語として妥当か（前後の空白は無視、それ以外は完全一致）。
  static bool isConfirmationValid(String input) =>
      input.trim() == confirmationPhrase;
}
