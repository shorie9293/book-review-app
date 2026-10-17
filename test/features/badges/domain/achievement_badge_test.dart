import 'package:book_review_app/features/badges/domain/achievement_badge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AchievementCategory', () {
    test('label と icon を持つ', () {
      expect(AchievementCategory.reading.label, '読了');
      expect(AchievementCategory.streak.label, '継続');
      expect(AchievementCategory.genre.label, 'ジャンル');
      expect(AchievementCategory.review.label, 'レビュー');
      expect(AchievementCategory.time.label, '読書時間');

      expect(AchievementCategory.reading.icon, isNotEmpty);
      expect(AchievementCategory.time.icon, isNotEmpty);
    });

    test('宣言順は reading, streak, genre, review, time', () {
      expect(
        AchievementCategory.values.map((c) => c.name).toList(),
        ['reading', 'streak', 'genre', 'review', 'time'],
      );
    });
  });

  group('AchievementBadgeDefinition', () {
    test('const 生成できる', () {
      const def = AchievementBadgeDefinition(
        id: 'finished_1',
        name: '最初の一冊',
        description: '1冊読了',
        category: AchievementCategory.reading,
        requiredCount: 1,
        unit: '冊',
      );
      expect(def.id, 'finished_1');
      expect(def.unit, '冊');
    });

    test('unit 省略時はカテゴリ既定の単位', () {
      const def = AchievementBadgeDefinition(
        id: 'x',
        name: 'n',
        description: 'd',
        category: AchievementCategory.time,
        requiredCount: 600,
      );
      expect(def.displayUnit, '分');
    });
  });

  group('AchievementBadgeProgress', () {
    AchievementBadgeDefinition def(int required, {AchievementCategory category = AchievementCategory.reading}) {
      return AchievementBadgeDefinition(
        id: 't_${required}_$category',
        name: 'test',
        description: 'test',
        category: category,
        requiredCount: required,
      );
    }

    test('current < 0 は 0 に丸められる', () {
      final p = AchievementBadgeProgress(definition: def(5), current: -3);
      expect(p.current, 0);
    });

    test('required <= 0 は ArgumentError', () {
      expect(
        () => AchievementBadgeProgress(definition: def(0), current: 1),
        throwsArgumentError,
      );
      expect(
        () => AchievementBadgeProgress(definition: def(-1), current: 1),
        throwsArgumentError,
      );
    });

    test('ratio は current / required', () {
      expect(AchievementBadgeProgress(definition: def(5), current: 3).ratio, closeTo(0.6, 1e-9));
    });

    test('ratio は 0.0..1.0 にクランプ', () {
      expect(AchievementBadgeProgress(definition: def(5), current: 0).ratio, 0.0);
      expect(AchievementBadgeProgress(definition: def(5), current: 25).ratio, 1.0);
    });

    test('required <= 0 の定義では ratio は 1.0', () {
      // required<=0 はコンストラクタで弾かれるが、防御仕様として契約を文書化
      final p = AchievementBadgeProgress(definition: def(1), current: 0);
      expect(p.required, 1);
    });

    test('percent', () {
      expect(AchievementBadgeProgress(definition: def(4), current: 3).percent, 75);
      expect(AchievementBadgeProgress(definition: def(4), current: 9).percent, 100);
    });

    test('isEarned: current >= required（ちょうどで獲得）', () {
      expect(AchievementBadgeProgress(definition: def(5), current: 4).isEarned, isFalse);
      expect(AchievementBadgeProgress(definition: def(5), current: 5).isEarned, isTrue);
      expect(AchievementBadgeProgress(definition: def(5), current: 25).isEarned, isTrue);
    });

    test('remaining', () {
      expect(AchievementBadgeProgress(definition: def(5), current: 3).remaining, 2);
      expect(AchievementBadgeProgress(definition: def(5), current: 7).remaining, 0);
    });

    test('progressLabel は "3 / 5 冊" 形式', () {
      final p = AchievementBadgeProgress(definition: def(5), current: 3);
      expect(p.progressLabel, '3 / 5 冊');
    });

    test('remainingLabel: 獲得済みと未獲得', () {
      expect(AchievementBadgeProgress(definition: def(5), current: 5).remainingLabel, '獲得済み');
      expect(AchievementBadgeProgress(definition: def(5), current: 3).remainingLabel, 'あと2冊');
      expect(AchievementBadgeProgress(definition: def(3, category: AchievementCategory.streak), current: 0).remainingLabel, 'あと3日');
    });
  });
}
