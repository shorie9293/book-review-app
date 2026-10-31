import 'package:flutter_test/flutter_test.dart';

import 'package:book_review_app/core/crash/crash_log_entry.dart';

void main() {
  group('CrashLogEntry', () {
    test('メッセージは先頭200字、スタックは先頭10フレームに切り詰める', () {
      final longMessage = 'あ' * 500;
      final frames = List<String>.generate(30, (i) => '#$i main.dart:$i');
      final stack = StackTrace.fromString(frames.join('\n'));

      final entry = CrashLogEntry.capture(
        timestamp: DateTime(2026, 1, 1, 12, 34),
        kind: 'flutter',
        error: longMessage,
        stack: stack,
      );

      expect(entry.message.length, CrashLogEntry.maxMessageLength);
      expect(entry.message, 'あ' * 200);
      expect(entry.stackTop.split('\n').length, CrashLogEntry.maxStackFrames);
      expect(entry.stackTop.startsWith('#0 main.dart:0'), isTrue);
      expect(entry.stackTop.contains('#10 '), isFalse);
    });

    test('短いメッセージ・null スタックはそのまま', () {
      final entry = CrashLogEntry.capture(
        timestamp: DateTime(2026, 1, 1),
        kind: 'zone',
        error: 'boom',
        stack: null,
      );
      expect(entry.message, 'boom');
      expect(entry.stackTop, '');
    });

    test('toJson / fromJson で往復できる', () {
      final entry = CrashLogEntry(
        timestamp: DateTime.utc(2026, 3, 4, 5, 6, 7),
        kind: 'platform',
        message: '例外です',
        stackTop: '#0 a.dart:1\n#1 b.dart:2',
      );

      final restored = CrashLogEntry.fromJson(entry.toJson());

      expect(restored, entry);
      expect(restored!.timestamp, entry.timestamp);
    });

    test('壊れた JSON は null を返す（例外を投げない）', () {
      expect(CrashLogEntry.fromJson(<String, dynamic>{}), isNull);
      expect(
        CrashLogEntry.fromJson(<String, dynamic>{
          'ts': 'not-a-date',
          'kind': 'flutter',
          'message': 'x',
        }),
        isNull,
      );
      expect(
        CrashLogEntry.fromJson(<String, dynamic>{
          'ts': '2026-01-01T00:00:00.000Z',
          'kind': 123,
          'message': 'x',
        }),
        isNull,
      );
    });

    test('値等価（全フィールド一致で等しく、hashCode も一致）', () {
      final a = CrashLogEntry(
        timestamp: DateTime.utc(2026),
        kind: 'flutter',
        message: 'm',
        stackTop: 's',
      );
      final b = CrashLogEntry(
        timestamp: DateTime.utc(2026),
        kind: 'flutter',
        message: 'm',
        stackTop: 's',
      );
      final c = CrashLogEntry(
        timestamp: DateTime.utc(2026),
        kind: 'zone',
        message: 'm',
        stackTop: 's',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });
}
