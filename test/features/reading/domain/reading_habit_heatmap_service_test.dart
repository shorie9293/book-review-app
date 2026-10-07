// 読書習慣ヒートマップ集計サービスの試練。
import 'package:book_review_app/features/reading/domain/reading_habit_heatmap.dart';
import 'package:book_review_app/features/reading/domain/reading_habit_heatmap_service.dart';
import 'package:book_review_app/features/reading/domain/reading_session.dart';
import 'package:flutter_test/flutter_test.dart';

ReadingSession _session(
  int year,
  int month,
  int day,
  int hour, {
  int minutes = 30,
}) {
  return ReadingSession(
    id: 's-$year-$month-$day-$hour-$minutes',
    startedAt: DateTime(year, month, day, hour),
    durationMinutes: minutes,
  );
}

/// durationMinutes を1未満に偽る防御テスト用フェイク。
class _WeirdSession implements ReadingSession {
  @override
  String get id => 'weird';
  @override
  DateTime get startedAt => DateTime(2026, 1, 5, 10);
  @override
  int get durationMinutes => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ReadingHabitHeatmapService.slotOfHour', () {
    test('hour境界: 0,3→0 / 4,7→1 / 8→2 / 23→5', () {
      expect(ReadingHabitHeatmapService.slotOfHour(0), 0);
      expect(ReadingHabitHeatmapService.slotOfHour(3), 0);
      expect(ReadingHabitHeatmapService.slotOfHour(4), 1);
      expect(ReadingHabitHeatmapService.slotOfHour(7), 1);
      expect(ReadingHabitHeatmapService.slotOfHour(8), 2);
      expect(ReadingHabitHeatmapService.slotOfHour(23), 5);
    });

    test('範囲外hourはclampされる', () {
      expect(ReadingHabitHeatmapService.slotOfHour(-5), 0);
      expect(ReadingHabitHeatmapService.slotOfHour(99), 5);
    });
  });

  group('labels', () {
    test('slotLabel', () {
      expect(ReadingHabitHeatmapService.slotLabel(0), '0-3時');
      expect(ReadingHabitHeatmapService.slotLabel(5), '20-23時');
      expect(ReadingHabitHeatmapService.slotLabel(-1), '—');
      expect(ReadingHabitHeatmapService.slotLabel(6), '—');
    });

    test('weekdayLabel', () {
      expect(ReadingHabitHeatmapService.weekdayLabel(1), '月');
      expect(ReadingHabitHeatmapService.weekdayLabel(7), '日');
      expect(ReadingHabitHeatmapService.weekdayLabel(0), '—');
      expect(ReadingHabitHeatmapService.weekdayLabel(8), '—');
    });
  });

  group('build: 空データ', () {
    test('空リスト→常に42セル・isEmpty・busiestはnull', () {
      final hm = ReadingHabitHeatmapService.build(sessions: const []);
      expect(hm.cells.length, 42);
      expect(hm.isEmpty, isTrue);
      expect(hm.maxMinutes, 0);
      expect(hm.totalMinutes, 0);
      expect(hm.totalSessions, 0);
      expect(hm.busiestWeekday, isNull);
      expect(hm.busiestSlot, isNull);
      expect(hm.busiestLabel, '—');
      expect(hm.cells.every((c) => c.minutes == 0), isTrue);
    });

    test('最小セッション（1分）→ busiest あり', () {
      final s = ReadingSession(
        id: 'a',
        startedAt: DateTime(2026, 1, 5, 10),
        durationMinutes: 1,
      );
      final hm = ReadingHabitHeatmapService.build(sessions: [s]);
      expect(hm.totalMinutes, 1);
      expect(hm.maxMinutes, 1);
      expect(hm.totalSessions, 1);
      expect(hm.busiestWeekday, 1);
      expect(hm.busiestSlot, 2);
      expect(hm.busiestLabel, '月曜 8-11時');
    });
  });

  group('build: 単一・複数セッション', () {
    test('単一セッションが正しいセルに入る', () {
      // 2026-01-05 は月曜
      final hm = ReadingHabitHeatmapService.build(
        sessions: [_session(2026, 1, 5, 10, minutes: 45)],
      );
      expect(hm.cellAt(1, 2).minutes, 45);
      expect(hm.totalMinutes, 45);
      expect(hm.totalSessions, 1);
      expect(hm.maxMinutes, 45);
      expect(hm.busiestWeekday, 1);
      expect(hm.busiestSlot, 2);
    });

    test('同セルへの複数セッションは加算される', () {
      final hm = ReadingHabitHeatmapService.build(
        sessions: [
          _session(2026, 1, 5, 10, minutes: 20),
          _session(2026, 1, 5, 11, minutes: 15),
        ],
      );
      expect(hm.cellAt(1, 2).minutes, 35);
      expect(hm.totalMinutes, 35);
      expect(hm.totalSessions, 2);
      expect(hm.cells.length, 42);
    });

    test('weekday境界: 月曜(1)と日曜(7)', () {
      // 2026-01-04 は日曜
      final hm = ReadingHabitHeatmapService.build(
        sessions: [
          _session(2026, 1, 5, 9, minutes: 10), // 月
          _session(2026, 1, 4, 9, minutes: 40), // 日
        ],
      );
      expect(hm.cellAt(1, 2).minutes, 10);
      expect(hm.cellAt(7, 2).minutes, 40);
      expect(hm.busiestWeekday, 7);
      expect(hm.weekdayTotals[0], 10);
      expect(hm.weekdayTotals[6], 40);
    });

    test('時間帯境界: hour 0,3,4,7,8,23 → slot 0,0,1,1,2,5', () {
      final hm = ReadingHabitHeatmapService.build(
        sessions: [
          _session(2026, 1, 5, 0, minutes: 1),
          _session(2026, 1, 5, 3, minutes: 2),
          _session(2026, 1, 5, 4, minutes: 4),
          _session(2026, 1, 5, 7, minutes: 8),
          _session(2026, 1, 5, 8, minutes: 16),
          _session(2026, 1, 5, 23, minutes: 32),
        ],
      );
      expect(hm.cellAt(1, 0).minutes, 3);
      expect(hm.cellAt(1, 1).minutes, 12);
      expect(hm.cellAt(1, 2).minutes, 16);
      expect(hm.cellAt(1, 5).minutes, 32);
      expect(hm.totalSessions, 6);
      expect(hm.totalMinutes, 63);
      expect(hm.busiestSlot, 5);
    });

    test('build 内部は durationMinutes<=0 を0として扱う（防御）', () {
      // ReadingSession のコンストラクタは1未満を弾くため、
      // サブクラスで防御パスのみを直接撃つ。
      final neg = _WeirdSession();
      final hm = ReadingHabitHeatmapService.build(
        sessions: [neg, _session(2026, 1, 5, 10, minutes: 30)],
      );
      expect(hm.totalSessions, 2);
      expect(hm.totalMinutes, 30);
      expect(hm.cellAt(1, 2).minutes, 30);
    });
  });

  group('maxMinutes と levelOf の4段階境界', () {
    test('levelOf 境界: ratio<=0.25→1, <=0.5→2, <=0.75→3, else→4', () {
      final hm = ReadingHabitHeatmapService.build(
        sessions: [
          // max=80。ratio: 20/80=0.25→1, 40/80=0.5→2, 60/80=0.75→3, 80/80→4
          _session(2026, 1, 5, 0, minutes: 20),
          _session(2026, 1, 5, 4, minutes: 40),
          _session(2026, 1, 5, 8, minutes: 60),
          _session(2026, 1, 5, 12, minutes: 80),
        ],
      );
      expect(hm.maxMinutes, 80);
      expect(hm.levelOf(hm.cellAt(1, 0)), 1);
      expect(hm.levelOf(hm.cellAt(1, 1)), 2);
      expect(hm.levelOf(hm.cellAt(1, 2)), 3);
      expect(hm.levelOf(hm.cellAt(1, 3)), 4);
      // 0分セル
      expect(hm.levelOf(hm.cellAt(1, 5)), 0);
    });

    test('max<=0 のとき levelOf は常に0', () {
      final hm = ReadingHabitHeatmapService.build(sessions: const []);
      expect(hm.levelOf(hm.cellAt(3, 3)), 0);
    });
  });

  group('weekdayTotals / slotTotals', () {
    test('長さと値が正しい', () {
      final hm = ReadingHabitHeatmapService.build(
        sessions: [
          _session(2026, 1, 5, 10, minutes: 30), // 月
          _session(2026, 1, 6, 21, minutes: 20), // 火
          _session(2026, 1, 6, 22, minutes: 10), // 火
          _session(2026, 1, 4, 8, minutes: 50), // 日
        ],
      );
      final wt = hm.weekdayTotals;
      final st = hm.slotTotals;
      expect(wt.length, 7);
      expect(st.length, 6);
      expect(wt, [30, 30, 0, 0, 0, 0, 50]);
      // slot2: 30(月10時)+50(日8時)=80, slot5: 30(火21,22時)
      expect(st[2], 80);
      expect(st[5], 30);
      expect(st.fold<int>(0, (a, b) => a + b), 110);
      expect(hm.totalMinutes, 110);
    });
  });

  group('busiest タイブレーク', () {
    test('曜日同数→小さい曜日番号（月優先）', () {
      final hm = ReadingHabitHeatmapService.build(
        sessions: [
          _session(2026, 1, 5, 10, minutes: 30), // 月
          _session(2026, 1, 6, 10, minutes: 30), // 火
        ],
      );
      expect(hm.busiestWeekday, 1);
    });

    test('slot同数→小さいslot', () {
      final hm = ReadingHabitHeatmapService.build(
        sessions: [
          _session(2026, 1, 5, 0, minutes: 30), // slot0
          _session(2026, 1, 5, 20, minutes: 30), // slot5
        ],
      );
      expect(hm.busiestSlot, 0);
    });
  });

  group('busiestLabel', () {
    test('文言: 火曜 20-23時', () {
      final hm = ReadingHabitHeatmapService.build(
        sessions: [_session(2026, 1, 6, 21, minutes: 30)], // 火曜21時
      );
      expect(hm.busiestLabel, '火曜 20-23時');
    });

    test('記録なしは —', () {
      final hm = ReadingHabitHeatmapService.build(sessions: const []);
      expect(hm.busiestLabel, '—');
    });
  });

  group('labels 全域', () {
    test('slotLabel 中間slot', () {
      expect(ReadingHabitHeatmapService.slotLabel(1), '4-7時');
      expect(ReadingHabitHeatmapService.slotLabel(2), '8-11時');
      expect(ReadingHabitHeatmapService.slotLabel(3), '12-15時');
      expect(ReadingHabitHeatmapService.slotLabel(4), '16-19時');
    });

    test('weekdayLabel 全曜日', () {
      const expect0 = ['月', '火', '水', '木', '金', '土', '日'];
      for (var i = 1; i <= 7; i++) {
        expect(ReadingHabitHeatmapService.weekdayLabel(i), expect0[i - 1]);
      }
    });
  });

  group('slotOfHour 全slot対応', () {
    test('各slotの代表hour', () {
      expect(ReadingHabitHeatmapService.slotOfHour(11), 2);
      expect(ReadingHabitHeatmapService.slotOfHour(12), 3);
      expect(ReadingHabitHeatmapService.slotOfHour(15), 3);
      expect(ReadingHabitHeatmapService.slotOfHour(16), 4);
      expect(ReadingHabitHeatmapService.slotOfHour(19), 4);
      expect(ReadingHabitHeatmapService.slotOfHour(20), 5);
    });
  });

  group('セルの等価性', () {
    test('==/hashCode', () {
      const a = ReadingHabitCell(weekday: 1, slot: 2, minutes: 30);
      const b = ReadingHabitCell(weekday: 1, slot: 2, minutes: 30);
      const c = ReadingHabitCell(weekday: 1, slot: 2, minutes: 31);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a == a, isTrue);
    });
  });

  group('levelOf の追加境界', () {
    test('最大セル自身は常に4', () {
      final hm = ReadingHabitHeatmapService.build(
        sessions: [_session(2026, 1, 5, 10, minutes: 7)],
      );
      expect(hm.levelOf(hm.cellAt(1, 2)), 4);
      expect(hm.maxMinutes, 7);
    });

    test('ratio が境界を跨ぐ場合（例 26/100→2）', () {
      final hm = ReadingHabitHeatmapService.build(
        sessions: [
          _session(2026, 1, 5, 0, minutes: 26),
          _session(2026, 1, 5, 20, minutes: 100),
        ],
      );
      expect(hm.levelOf(hm.cellAt(1, 0)), 2); // 0.26
      expect(hm.levelOf(hm.cellAt(1, 5)), 4); // 1.0
    });
  });

  group('複数曜日の合計集計', () {
    test('5セッション・複数曜日×時間帯の分散', () {
      final hm = ReadingHabitHeatmapService.build(
        sessions: [
          _session(2026, 1, 5, 0, minutes: 10), // 月 slot0
          _session(2026, 1, 6, 5, minutes: 10), // 火 slot1
          _session(2026, 1, 7, 12, minutes: 10), // 水 slot3
          _session(2026, 1, 8, 17, minutes: 10), // 木 slot4
          _session(2026, 1, 9, 21, minutes: 10), // 金 slot5
        ],
      );
      expect(hm.totalSessions, 5);
      expect(hm.totalMinutes, 50);
      expect(hm.maxMinutes, 10);
      expect(hm.weekdayTotals, [10, 10, 10, 10, 10, 0, 0]);
      expect(hm.slotTotals, [10, 10, 0, 10, 10, 10]);
      expect(hm.busiestWeekday, 1);
      expect(hm.busiestSlot, 0);
      expect(hm.busiestLabel, '月曜 0-3時');
      expect(hm.isEmpty, isFalse);
    });

    test('合計0分データは全0データと同じ挙動', () {
      final hm = ReadingHabitHeatmapService.build(
        sessions: [
          _WeirdSession(),
        ],
      );
      expect(hm.cells.length, 42);
      expect(hm.totalSessions, 1);
      expect(hm.totalMinutes, 0);
      expect(hm.maxMinutes, 0);
      expect(hm.busiestWeekday, isNull);
      expect(hm.busiestSlot, isNull);
      expect(hm.busiestLabel, '—');
      expect(hm.isEmpty, isFalse);
      expect(hm.cells.every((c) => c.isEmpty), isTrue);
      expect(hm.levelOf(hm.cellAt(4, 4)), 0);
    });
  });

  group('モデルの様式', () {
    test('cellAt の index 規約と等価性', () {
      final hm = ReadingHabitHeatmapService.build(
        sessions: [_session(2026, 1, 5, 10, minutes: 30)],
      );
      // index = (weekday-1)*6 + slot
      expect(hm.cells[(1 - 1) * 6 + 2], hm.cellAt(1, 2));
      expect(hm.cellAt(1, 2), const ReadingHabitCell(weekday: 1, slot: 2, minutes: 30));
      expect(hm.cellAt(1, 2).isEmpty, isFalse);
      expect(hm.cellAt(2, 2).isEmpty, isTrue);
      expect(
        hm.cellAt(1, 2).toString(),
        'ReadingHabitCell(weekday: 1, slot: 2, minutes: 30)',
      );
    });

    test('isEmpty getter は totalSessions 基準', () {
      final empty = ReadingHabitHeatmapService.build(sessions: const []);
      expect(empty.isEmpty, isTrue);
      final one = ReadingHabitHeatmapService.build(
        sessions: [_session(2026, 1, 5, 10, minutes: 1)],
      );
      expect(one.isEmpty, isFalse);
    });
  });
}
