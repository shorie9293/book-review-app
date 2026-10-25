/// クロスアプリ連携コード（リンクコード）の純粋ロジック。
///
/// rpg-task 側はイベントの `user_id` と手動入力されたリンクコードを
/// `userId.startsWith(linkedUserId)` で照合する
/// （参照: rpg-task/lib/features/crossapp/data/cross_app_reward_service.dart）。
/// そのため UI には「userId の先頭8文字」をリンクコードとして提示する。
library;

/// [userId] の先頭8文字（trim後）。空なら ''。
///
/// 8文字未満の ID は trim 後の全体を返す（短い ID でもリンク可能にする）。
String linkCodeOf(String userId) {
  final trimmed = userId.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.length <= 8 ? trimmed : trimmed.substring(0, 8);
}

/// 8文字の英数字か。
///
/// リンクコードは rpg-task の設定画面で手入力されるため、
/// 紛らわしい記号・空白・非ASCIIは受け付けない。
bool isValidLinkCode(String code) {
  if (code.length != 8) return false;
  return RegExp(r'^[A-Za-z0-9]{8}$').hasMatch(code);
}
