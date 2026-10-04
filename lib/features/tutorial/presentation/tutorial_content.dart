import 'package:flutter/material.dart';
import 'package:book_review_app/features/tutorial/domain/tutorial_step.dart';

/// チュートリアル1ページ分の表示データ。
class TutorialPageData {
  /// ページ識別子（'page_tutorial_(step名)' 形式推奨）。
  final String keyName;

  /// 見出し用アイコン。
  final IconData icon;

  /// 見出し。
  final String title;

  /// 本文。
  final String body;

  /// チュートリアル1ページ分の表示データを生成する。
  const TutorialPageData({
    required this.keyName,
    required this.icon,
    required this.title,
    required this.body,
  });

  /// 試練（テスト）用の Key。
  Key get pageKey => Key(keyName);
}

/// チュートリアルのページ定義を一元管理する静的コンテンツ。
class TutorialContent {
  TutorialContent._();

  /// TutorialStep の宣言順に生成された全ページ。
  static final List<TutorialPageData> pages = TutorialStep.values
      .map(
        (step) => TutorialPageData(
          keyName: 'page_tutorial_${step.name}',
          icon: switch (step) {
            TutorialStep.bookshelf => Icons.menu_book,
            TutorialStep.addBook => Icons.add_circle_outline,
            TutorialStep.review => Icons.rate_review_outlined,
            TutorialStep.notes => Icons.sticky_note_2_outlined,
            TutorialStep.queue => Icons.bookmarks_outlined,
          },
          title: step.label,
          body: step.description,
        ),
      )
      .toList(growable: false);

  /// 総ページ数。
  static int get pageCount => pages.length;
}
