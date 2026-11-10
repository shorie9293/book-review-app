import 'package:book_review_app/domain/models/book.dart';
import 'package:book_review_app/domain/models/book_note.dart';
import 'package:book_review_app/domain/models/review.dart';
import 'package:book_review_app/features/backup/domain/backup_models.dart';
import 'package:book_review_app/features/backup/domain/backup_service.dart';

/// 一覧表示に出す追加対象の既定件数。
const int kRestorePreviewSampleLimit = 5;

/// プレビューの内訳行が扱うデータ種別。
///
/// book のバックアップは蔵書・レビュー・読書メモの3種のみ
/// （読書セッションは [BackupBundle] の対象外）。
enum RestorePreviewKind {
  book('蔵書', '冊'),
  review('レビュー', '件'),
  note('メモ', '件');

  const RestorePreviewKind(this.label, this.unit);

  /// 表示用の種別名（例: 蔵書）。
  final String label;

  /// 件数の単位（例: 冊）。
  final String unit;
}

/// 追加対象1件の表示用サンプル。
class RestorePreviewSample implements Comparable<RestorePreviewSample> {
  /// データ種別。
  final RestorePreviewKind kind;

  /// 追加対象の id（並び順の決定的な基準）。
  final String id;

  /// 画面に出す見出し（書名・レビュー本文・メモ本文の抜粋）。
  final String label;

  const RestorePreviewSample({
    required this.kind,
    required this.id,
    required this.label,
  });

  /// 箇条書き1行（例: `・蔵書「吾輩は猫である」`）。
  String get display => '・${kind.label}「$label」';

  @override
  int compareTo(RestorePreviewSample other) {
    final byKind = kind.index.compareTo(other.kind.index);
    if (byKind != 0) return byKind;
    return id.compareTo(other.id);
  }
}

/// 復元前プレビュー（内訳＋追加対象の抜粋＋文言）。
///
/// 手動復元（[BackupService.merge]）の**既存優先・上書きしない**意味論に
/// 忠実な表示を作る純粋クラス。kozuchi の同名クラスが扱う「上書き件数」は
/// book には存在しないため、追加件数・重複スキップ件数・種別内訳に置き換える。
///
/// 「0件のときどう言うか」という分岐はすべてこのクラスに閉じ込め、
/// 画面側は文字列を並べるだけにする（widget に if を散らさない）。
class RestorePreview {
  /// 蔵書の追加件数。
  final int booksAdded;

  /// レビューの追加件数。
  final int reviewsAdded;

  /// メモの追加件数。
  final int notesAdded;

  /// 蔵書のうち既存と重複してスキップした件数。
  final int booksSkipped;

  /// レビューのうち既存と重複してスキップした件数。
  final int reviewsSkipped;

  /// メモのうち既存と重複してスキップした件数。
  final int notesSkipped;

  /// 追加対象の先頭 [kRestorePreviewSampleLimit] 件（種別→id の昇順）。
  final List<RestorePreviewSample> addedSamples;

  /// 抜粋から漏れた追加対象件数。
  final int hiddenAddedCount;

  const RestorePreview({
    required this.booksAdded,
    required this.reviewsAdded,
    required this.notesAdded,
    required this.booksSkipped,
    required this.reviewsSkipped,
    required this.notesSkipped,
    required this.addedSamples,
    required this.hiddenAddedCount,
  });

  /// 追加される総件数。
  int get totalAdded => booksAdded + reviewsAdded + notesAdded;

  /// 既存と重複してスキップされる総件数。
  int get totalSkipped => booksSkipped + reviewsSkipped + notesSkipped;

  /// バックアップに含まれる対象の総件数。
  int get total => totalAdded + totalSkipped;

  /// 追加が1件でも起きるか。
  bool get hasAdditions => totalAdded > 0;

  /// 要約行。例: `追加 12件 / スキップ 3件`
  String get summary => '追加 $totalAdded件 / スキップ $totalSkipped件';

  /// 種別ごとの内訳行（蔵書・レビュー・メモの順）。
  ///
  /// 例:
  /// ```
  /// ・蔵書: 追加 2冊 / 重複 0冊
  /// ・レビュー: 追加 1件 / 重複 3件
  /// ・メモ: 追加 0件 / 重複 0件
  /// ```
  List<String> get breakdownLines => [
        _breakdownLine(RestorePreviewKind.book, booksAdded, booksSkipped),
        _breakdownLine(RestorePreviewKind.review, reviewsAdded, reviewsSkipped),
        _breakdownLine(RestorePreviewKind.note, notesAdded, notesSkipped),
      ];

  /// [breakdownLines] を改行で連結した表示用文字列。
  String get breakdown => breakdownLines.join('\n');

  /// 追加対象の抜粋。追加0件なら null（表示しない）。
  ///
  /// 例:
  /// ```
  /// 追加されるデータ（先頭 5件）:
  /// ・蔵書「吾輩は猫である」
  /// ・メモ「第3章の引用」
  /// ほか 2件
  /// ```
  String? get samplesText {
    if (addedSamples.isEmpty) return null;
    final buffer = StringBuffer('追加されるデータ（先頭 ${addedSamples.length}件）:');
    for (final sample in addedSamples) {
      buffer.write('\n${sample.display}');
    }
    if (hiddenAddedCount > 0) {
      buffer.write('\nほか $hiddenAddedCount件');
    }
    return buffer.toString();
  }

  /// 状況に応じた一文（境界ごとに言い回しを変える）。
  String get message {
    if (total == 0) return '復元するデータはありません';
    if (totalAdded == 0) return '追加されるデータはありません（すべて既存データと重複しています）';
    return '既存データは上書きされません（追加のみ行われます）';
  }

  /// [incoming] を [existing] へマージした結果のプレビューを組み立てる。
  ///
  /// 件数は [BackupService.merge] の結果をそのまま使う（表示と実挙動を
  /// 一つの実装に揃えるため）。追加対象の抜粋だけを本クラスで再走査する。
  ///
  /// 不正な [sampleLimit] は 0 として扱う（画面都合で落とさない）。
  /// 引数の型が正しければ例外は投げない。
  static RestorePreview build({
    required BackupBundle incoming,
    required BackupBundle existing,
    int sampleLimit = kRestorePreviewSampleLimit,
  }) {
    final merge = const BackupService().merge(
      incoming: incoming,
      existingBooks: existing.books,
      existingReviews: existing.reviews,
      existingNotes: existing.notes,
    );

    final limit = sampleLimit < 0 ? 0 : sampleLimit;
    final allAdded = <RestorePreviewSample>[
      ..._addedBooks(incoming, existing),
      ..._addedReviews(incoming, existing),
      ..._addedNotes(incoming, existing),
    ]..sort();

    final samples = List<RestorePreviewSample>.unmodifiable(
      allAdded.take(limit),
    );

    return RestorePreview(
      booksAdded: merge.booksAdded,
      reviewsAdded: merge.reviewsAdded,
      notesAdded: merge.notesAdded,
      booksSkipped: merge.booksSkipped,
      reviewsSkipped: merge.reviewsSkipped,
      notesSkipped: merge.notesSkipped,
      addedSamples: samples,
      hiddenAddedCount: allAdded.length - samples.length,
    );
  }

  /// 破損・空・型違いでも落ちない [build]。組み立て不能なら null。
  ///
  /// 画面は null を「プレビュー非表示」として扱えばよい。
  static RestorePreview? tryBuild({
    required BackupBundle? incoming,
    required BackupBundle? existing,
    int sampleLimit = kRestorePreviewSampleLimit,
  }) {
    if (incoming == null || existing == null) return null;
    try {
      return build(
        incoming: incoming,
        existing: existing,
        sampleLimit: sampleLimit,
      );
    } catch (_) {
      return null;
    }
  }

  /// JSON 文字列からプレビューを組み立てる（破損・空・巨大入力でも落ちない）。
  ///
  /// パース不能・null は null（＝プレビュー非表示）。
  static RestorePreview? tryBuildFromJson({
    required String? json,
    required BackupBundle? existing,
    BackupService service = const BackupService(),
    int sampleLimit = kRestorePreviewSampleLimit,
  }) {
    if (json == null || json.isEmpty || existing == null) return null;
    try {
      return build(
        incoming: service.parse(json),
        existing: existing,
        sampleLimit: sampleLimit,
      );
    } catch (_) {
      return null;
    }
  }

  static String _breakdownLine(
    RestorePreviewKind kind,
    int added,
    int skipped,
  ) =>
      '・${kind.label}: 追加 $added${kind.unit} / 重複 $skipped${kind.unit}';

  /// 追加対象の蔵書（incoming 内の重複id は先勝ちで畳む）。
  static List<RestorePreviewSample> _addedBooks(
    BackupBundle incoming,
    BackupBundle existing,
  ) {
    final existingIds = existing.books.map((b) => b.id).toSet();
    final seen = <String>{};
    final added = <RestorePreviewSample>[];
    for (final Book book in incoming.books) {
      if (!seen.add(book.id)) continue;
      if (existingIds.contains(book.id)) continue;
      added.add(RestorePreviewSample(
        kind: RestorePreviewKind.book,
        id: book.id,
        label: _abbreviate(book.title),
      ));
    }
    return added;
  }

  /// 追加対象のレビュー（incoming 内の重複id は先勝ちで畳む）。
  static List<RestorePreviewSample> _addedReviews(
    BackupBundle incoming,
    BackupBundle existing,
  ) {
    final existingIds = existing.reviews.map((r) => r.id).toSet();
    final seen = <String>{};
    final added = <RestorePreviewSample>[];
    for (final Review review in incoming.reviews) {
      if (!seen.add(review.id)) continue;
      if (existingIds.contains(review.id)) continue;
      added.add(RestorePreviewSample(
        kind: RestorePreviewKind.review,
        id: review.id,
        label: _abbreviate(review.text),
      ));
    }
    return added;
  }

  /// 追加対象のメモ（incoming 内の重複id は先勝ちで畳む）。
  static List<RestorePreviewSample> _addedNotes(
    BackupBundle incoming,
    BackupBundle existing,
  ) {
    final existingIds = existing.notes.map((n) => n.id).toSet();
    final seen = <String>{};
    final added = <RestorePreviewSample>[];
    for (final BookNote note in incoming.notes) {
      if (!seen.add(note.id)) continue;
      if (existingIds.contains(note.id)) continue;
      added.add(RestorePreviewSample(
        kind: RestorePreviewKind.note,
        id: note.id,
        label: _abbreviate(note.content),
      ));
    }
    return added;
  }

  /// 一覧行を1行に収めるための抜粋（末尾は `…`）。
  static String _abbreviate(String value, [int max = 24]) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '(無題)';
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max)}…';
  }
}
