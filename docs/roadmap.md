# 【book-review-app 道標】

**制定**: 令和八年皐月十二日
**改訂**: 令和八年水無月十五日（2026年6月15日）— イシコリドメ
**種別**: Flutterアプリ（Feature-First構造）
**状態**: 🟢 蔵書API連携✅ + レビュー機能✅ + ISBNバーコードスキャン✅ + 開顕準備進行中
**試験**: 136/136通過 ✅ / dart analyze clean ✅
**バージョン**: 1.0.0+2

---

## 現状

| 要素 | 状態 |
|------|------|
| Flutter雛形 | ✅ Feature-First構造 |
| 本棚画面 | ✅ ISBN検索 + 蔵書一覧 + 追加・削除機能 + バーコードスキャン連携 |
| ISBNバーコードスキャン | ✅ BarcodeScannerScreen（MobileScanner + scanWindow + debounce + 確認ダイアログ） |
| レビュー機能 | ✅ HiveReviewRepository + ReviewScreen（星評価＋テキスト＋一覧＋追加・編集・削除） |
| 蔵書API連携 | ✅ OpenBD API連携 + HiveBookRepository + 蔵書登録フロー |
| 試験 | 116件（単体19件 + Widget 36件 + 統合4件 + スキャン画面3件 + 既存54件の拡充） |

---

## 優先タスク

### ✅ 蔵書API連携（皐月二十二日 夕刻——イシコリ）
- [x] OpenBD API 連携（BookSearchService: http.Client DI対応）
- [x] HiveBookRepository（BookRepositoryインターフェースの完全実装）
- [x] 書籍検索→蔵書登録フロー（BookshelfScreen: 検索→確認→追加→一覧表示→削除）
- [x] 試験: 単体12件（検索4件 + Repository 8件）+ Widget 4件 = 全31件通過
- [x] pubspec: hive, hive_flutter, uuid 追加
- コミット: `32adcb2`

### ✅ レビュー機能（皐月二十二日 夜刻——イシコリ）
- [x] HiveReviewRepository（Hive Box 'reviews' 使用、JSONシリアライズ）
- [x] ReviewScreen（レビュー一覧 + 追加 + 編集 + 削除）
- [x] ReviewCard（星評価★/☆ + テキスト + 日付 + 編集・削除ボタン）
- [x] ReviewForm（5段階星タップ + テキスト入力 + 保存・キャンセル）
- [x] BookshelfScreen連携（蔵書タップ→ReviewScreenへ遷移）
- [x] 試験: 単体7件 + Widget 18件 = 新規24件（全54件通過）
- コミット: `17ac36d`

### 🟢 試験拡充
- [x] ViewModel/Providerテスト（BookshelfViewModel/BarcodeScannerViewModel/ReviewViewModel Test — 皐月二十五日時点で実装済み）
- [x] レビュー画面のWidgetテスト拡充（ReviewCard/ReviewForm/ReviewScreen — 皐月二十五日時点で実装済み）
- [x] ISBNバーコードスキャン連携テスト（BarcodeScannerScreen 3件 + BookshelfScreen遷移1件 — 皐月十日時点で実装済み）
- [x] カバレッジ70%達成（71.4%達成。coverage.sh導入 + genhtml HTMLレポート生成）

### ✅ ISBNバーコードスキャン（皐月二十二日 夜刻——イシコリ）
- [x] `mobile_scanner: ^6.0.0` 導入 + Android CAMERA権限
- [x] BarcodeScannerScreen（MobileScanner + scanWindow + 2.5s debounce + 確認ダイアログ）
- [x] BookshelfScreen連携（スキャンボタン→Navigator.push→結果受取→本棚追加）
- [x] 試験: 4件追加（スキャン画面3件 + 本棚連携1件 = 全62件通過）
- コミット: `b4c3c3b`

---

**優先度**: 中。Kozuchi/tsundoku-quest開顕待ち。蔵書API連携・レビュー機能・ISBNバーコードスキャンの基盤は完了。試験136/136通過（皐月三十一日 MainScreen Test追加）。開顕準備が次。

**更新履歴**: 皐月三十一日 夜刻（イシコリ）— 道標更新：試験実測136/136通過を反映。MainScreen test追加。皐月三十日 朝刻（イシコリ）— 試験拡充 (+20) で116通過。commit `903aac4`。

---

### 🟢 開顕準備（水無月十五日——イシコリドメ）

| 項目 | 状態 |
|------|------|
| gitignore | ✅ 完了 |
| privacy-policy.md | ✅ 完了 |
| store-description.md | ✅ 完了 |
| Gemfile | ✅ 完了 |
| feature_graphic.png（1024x500） | ✅ 完了 |
| icon.png（1024x1024） | ✅ 完了 |
| generate_upload_key.sh | ✅ 完了 |
| CI/CDワークフロー（flutter-ci.yml + deploy.yml） | ⬜ 未了 |
| fastlane Appfile / Fastfile | ⬜ 未了 |
| GitHubリポジトリ作成（gh auth 要） | ⬜ 未了 |
| 署名鍵実生成（keytool 要） | ⬜ 未了 |

**コミット**: `f9282f1` + `c0b9052`
