import 'package:levit_monitor/levit_monitor.dart' as lm;
import 'package:test/test.dart';

void main() {
  group('LevitConsoleTransport formats log events', () {
    test('formats minimal LevitLogEvent correctly', () {
      final lines = <String>[];
      final transport = lm.LevitConsoleTransport(
        formatter: (_, message) => message,
        output: lines.add,
      );

      final event = lm.LevitLogEvent(
        sessionId: 'test-session',
        level: lm.LevitLogLevel.info,
        data: 'A simple log message',
      );

      transport.send(event);
      expect(lines.last, 'LOG: A simple log message');
    });

    test('formats LevitLogEvent with error and stackTrace', () {
      final lines = <String>[];
      final transport = lm.LevitConsoleTransport(
        formatter: (_, message) => message,
        output: lines.add,
      );

      final event = lm.LevitLogEvent(
        sessionId: 'test-session',
        level: lm.LevitLogLevel.error,
        data: 'Failed operation',
        error: 'Timeout Exception',
        stackTrace: StackTrace.fromString('frame_1\nframe_2'),
      );

      transport.send(event);
      final output = lines.last;
      expect(output, contains('LOG: Failed operation'));
      expect(output, contains('Error: Timeout Exception'));
      expect(output, contains('Stack: \nframe_1\nframe_2'));
    });
  });
}
