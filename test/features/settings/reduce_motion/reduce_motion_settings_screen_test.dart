import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_review_app/core/theme/reduce_motion_repository.dart';
import 'package:book_review_app/core/theme/reduce_motion_setting.dart';
import 'package:book_review_app/screens/reduce_motion_settings_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('ReduceMotionSettingsScreen', () {
    testWidgets('3択（システム/動きを有効/動きを減らす）が描画される', (tester) async {
      await tester.pumpWidget(_wrap(
        ReduceMotionSettingsScreen(
          repository: InMemoryReduceMotionRepository(),
          initial: ReduceMotionSetting.system,
        ),
      ));

      for (final setting in ReduceMotionSetting.values) {
        expect(
          find.byKey(ValueKey('reduce_motion_option_${setting.storageKey}')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('reduce_motion_option_system')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('reduce_motion_option_off')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('reduce_motion_option_on')), findsOneWidget);
      expect(find.text('動きを減らす'), findsWidgets);
    });

    testWidgets('選択肢をタップすると repository.save に到達する', (tester) async {
      final repo = InMemoryReduceMotionRepository();
      await tester.pumpWidget(_wrap(
        ReduceMotionSettingsScreen(
          repository: repo,
          initial: ReduceMotionSetting.system,
        ),
      ));

      await tester.tap(find.byKey(const ValueKey('reduce_motion_option_on')));
      await tester.pumpAndSettle();

      expect(repo.saveCount, 1);
      expect(repo.saved, ReduceMotionSetting.on);
    });

    testWidgets('注入した initial が選択状態として反映される', (tester) async {
      await tester.pumpWidget(_wrap(
        ReduceMotionSettingsScreen(
          repository: InMemoryReduceMotionRepository(),
          initial: ReduceMotionSetting.off,
        ),
      ));

      final tile = tester.widget<RadioListTile<ReduceMotionSetting>>(
        find.byKey(const ValueKey('reduce_motion_option_off')),
      );
      expect(tile.groupValue, ReduceMotionSetting.off);
    });

    testWidgets('変更時に onChanged が発火する', (tester) async {
      final received = <ReduceMotionSetting>[];
      await tester.pumpWidget(_wrap(
        ReduceMotionSettingsScreen(
          repository: InMemoryReduceMotionRepository(),
          initial: ReduceMotionSetting.system,
          onChanged: received.add,
        ),
      ));

      await tester.tap(find.byKey(const ValueKey('reduce_motion_option_off')));
      await tester.pumpAndSettle();

      expect(received, [ReduceMotionSetting.off]);
    });
  });
}
