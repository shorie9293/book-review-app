/// 控え（バックアップ JSON）に載せる設定の許可リスト。
///
/// **許可リスト方式**。ここに列挙した実在キーだけが控えに載る
/// （プレフィックス一括取得は禁止。設定ボックスには秘密も同居するため）。
/// 新しい設定を控えに載せたい時は、実在キーを grep で確認して
/// [kBackupSettingSpecs] へ1行足す。
///
/// 実在キーの出所:
/// - `book_review_theme_mode` … ThemeModeRepository（'settings' ボックス）
/// - `book_reduce_motion` … ReduceMotionRepository（'settings' ボックス）
/// - `book_review_text_scale` … TextScaleRepository（'settings_scalars' ボックス）
/// - `book_review_tutorial_completed` … HiveTutorialRepository
///   （'tutorial_settings' ボックス）
/// - `app_lock.*` … HiveAppLockRepository（'settings' ボックス・**秘密**）
library;

/// 設定の区分（復元UI・報告でのまとめ単位）。
enum BackupSettingCategory {
  /// 表示・操作に関する設定（テーマ・文字サイズ・動き）。
  settings,

  /// 初回導線の状態（チュートリアル完了など）。
  tutorial,
}

/// 控えに載せる設定1項目の仕様。
class BackupSettingSpec {
  /// 仕様を生成する。
  const BackupSettingSpec({
    required this.key,
    required this.category,
    required this.label,
    this.isSecret = false,
  });

  /// 永続化キー（保存キーそのもの）。
  final String key;

  /// 区分。
  final BackupSettingCategory category;

  /// 復元UI・報告で使う表示名。
  final String label;

  /// 秘密（控えに載せてはならない）。app_lock 系・トークン系が該当する。
  final bool isSecret;
}

/// 設定バンドル内のスキーマ版（本体の [kBackupSchemaVersion] とは独立）。
///
/// settings の構造を壊す時だけ増やす。未知の版は読まずに捨てる。
const int kBackupSettingsSchemaVersion = 1;

/// 控えに載せる設定の許可リスト。
///
/// 秘密（app_lock 系）も「載せない」ことを明示するために列挙する。
const List<BackupSettingSpec> kBackupSettingSpecs = <BackupSettingSpec>[
  BackupSettingSpec(
    key: 'book_review_theme_mode',
    category: BackupSettingCategory.settings,
    label: 'テーマ',
  ),
  BackupSettingSpec(
    key: 'book_review_text_scale',
    category: BackupSettingCategory.settings,
    label: '文字サイズ',
  ),
  BackupSettingSpec(
    key: 'book_reduce_motion',
    category: BackupSettingCategory.settings,
    label: '動きを減らす',
  ),
  BackupSettingSpec(
    key: 'book_review_tutorial_completed',
    category: BackupSettingCategory.tutorial,
    label: 'チュートリアル完了',
  ),
  // --- ここから下は秘密。控えには決して載せない（isSecret で落とす）。 ---
  BackupSettingSpec(
    key: 'app_lock.enabled',
    category: BackupSettingCategory.settings,
    label: 'アプリロック有効',
    isSecret: true,
  ),
  BackupSettingSpec(
    key: 'app_lock.method',
    category: BackupSettingCategory.settings,
    label: 'アプリロック方式',
    isSecret: true,
  ),
  BackupSettingSpec(
    key: 'app_lock.passcode_hash',
    category: BackupSettingCategory.settings,
    label: 'パスコードハッシュ',
    isSecret: true,
  ),
  BackupSettingSpec(
    key: 'app_lock.relock_grace_seconds',
    category: BackupSettingCategory.settings,
    label: '再施錠猶予',
    isSecret: true,
  ),
  BackupSettingSpec(
    key: 'app_lock.failed_attempts',
    category: BackupSettingCategory.settings,
    label: '連続失敗回数',
    isSecret: true,
  ),
  BackupSettingSpec(
    key: 'app_lock.locked_until_epoch_ms',
    category: BackupSettingCategory.settings,
    label: 'ロックアウト解除時刻',
    isSecret: true,
  ),
];

/// キーから仕様を引く（未知キーは null）。
BackupSettingSpec? backupSettingSpecFor(String key) {
  for (final spec in kBackupSettingSpecs) {
    if (spec.key == key) return spec;
  }
  return null;
}

/// 生の設定マップから、控えに載せてよい値だけを抜き出す。
///
/// - 許可リストに無いキーは落とす（未知キーの混入を防ぐ）
/// - [BackupSettingSpec.isSecret] のキーは落とす
/// - null・非スカラ（Map/List 等）は落とす（JSON で往復できないため）
Map<String, Object?> selectForBackup(Map<String, Object?> raw) {
  final selected = <String, Object?>{};
  for (final spec in kBackupSettingSpecs) {
    if (spec.isSecret) continue;
    final value = raw[spec.key];
    if (!_isJsonScalar(value)) continue;
    selected[spec.key] = value;
  }
  return selected;
}

/// 設定バンドル（settings セクション）の本体。
///
/// 破損 JSON で本体の復元を巻き添えにしないため、[tryFromJson] は
/// 例外を投げずに null を返す（設定は「あれば得する」任意項目）。
class BackupSettingsBundle {
  /// バンドルを生成する。
  const BackupSettingsBundle({
    this.schemaVersion = kBackupSettingsSchemaVersion,
    required this.values,
  });

  /// 設定バンドル内のスキーマ版。
  final int schemaVersion;

  /// 設定キー → 値（JSON スカラのみ）。
  final Map<String, Object?> values;

  /// JSON へ直列化する。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'values': Map<String, Object?>.of(values),
      };

  /// JSON から復元する。非Map・破損は **throw せず null**。
  static BackupSettingsBundle? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final version = raw['schemaVersion'];
    if (version is! int || version < 1) return null;
    final values = raw['values'];
    if (values is! Map) return null;

    final restored = <String, Object?>{};
    values.forEach((key, value) {
      if (key is! String) return;
      if (!_isJsonScalar(value)) return;
      restored[key] = value;
    });
    return BackupSettingsBundle(schemaVersion: version, values: restored);
  }
}

/// JSON で往復できるスカラか（String / num / bool のみ許可）。
bool _isJsonScalar(Object? value) =>
    value is String || value is num || value is bool;
