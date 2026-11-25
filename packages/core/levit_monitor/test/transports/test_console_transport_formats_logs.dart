import 'package:levit_monitor/levit_monitor.dart' as lm;
import 'package:logger/logger.dart' as logger;
import 'package:test/test.dart';

class _MockLogPrinter extends logger.LogPrinter {
  final List<String> lines = [];

  @override
  List<String> log(logger.LogEvent event) {
    lines.add(event.message.toString());
    return [];
  }
}

void main() {
  group('LevitConsoleTransport formats log events', () {
    test('formats minimal LevitLogEvent correctly', () {
      final printer = _MockLogPrinter();
      final transport = lm.LevitConsoleTransport(printer: printer);

      final event = lm.LevitLogEvent(
        sessionId: 'test-session',
        level: lm.LevitLogLevel.info,
        data: 'A simple log message',
      );

      transport.send(event);
      expect(printer.lines.last, 'LOG: A simple log message');
    });

    test('formats LevitLogEvent with error and stackTrace', () {
      final printer = _MockLogPrinter();
      final transport = lm.LevitConsoleTransport(printer: printer);

      final event = lm.LevitLogEvent(
        sessionId: 'test-session',
        level: lm.LevitLogLevel.error,
        data: 'Failed operation',
        error: 'Timeout Exception',
        stackTrace: StackTrace.fromString('frame_1\nframe_2'),
      );

      transport.send(event);
      final output = printer.lines.last;
      expect(output, contains('LOG: Failed operation'));
      expect(output, contains('Error: Timeout Exception'));
      expect(output, contains('Stack: \nframe_1\nframe_2'));
    });
  });
}
