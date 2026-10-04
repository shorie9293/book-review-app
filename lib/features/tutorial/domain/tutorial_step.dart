/// チュートリアルの各ステップ定義。
///
/// 初回オンボーディングで順番に案内するアプリの主要機能を列挙する。
enum TutorialStep {
  /// 書庫（本の一覧）の案内。
  bookshelf,

  /// 本を追加する手順の案内。
  addBook,

  /// レビュー作成の案内。
  review,

  /// メモ・引用機能の案内。
  notes,

  /// 次に読むキューの案内。
  queue,
}

/// 各ステップの短いラベルを提供する拡張。
extension TutorialStepLabel on TutorialStep {
  /// UI 表示用の短いラベル。
  String get label {
    switch (this) {
      case TutorialStep.bookshelf:
        return '書庫';
      case TutorialStep.addBook:
        return '本を追加';
      case TutorialStep.review:
        return 'レビュー';
      case TutorialStep.notes:
        return 'メモ・引用';
      case TutorialStep.queue:
        return '次に読む';
    }
  }
}

/// 各ステップの案内文を提供する拡張。
extension TutorialStepDescription on TutorialStep {
  /// ステップの案内文（1〜2文・日本語）。
  String get description {
    switch (this) {
      case TutorialStep.bookshelf:
        return 'あなたの本がすべて並ぶ書庫です。読んだ本、読んでいる本をここで一覧できます。';
      case TutorialStep.addBook:
        return '本を追加して読書記録を始めましょう。タイトルや著者を入力して書庫に登録します。';
      case TutorialStep.review:
        return '読み終えた本にレビューを書きましょう。評価や感想を記録して自分だけの書評が育ちます。';
      case TutorialStep.notes:
        return '気になった一文や読書メモを残せます。あとで見返して学びを深めましょう。';
      case TutorialStep.queue:
        return '次に読みたい本をキューに登録。積ん読を解消する読書計画に役立ちます。';
    }
  }
}
