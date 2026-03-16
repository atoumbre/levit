import 'package:levit_monitor/levit_monitor.dart';
import 'package:logger/logger.dart' hide LogEvent;
import 'package:test/test.dart';

class _FakeTransport implements LevitTransport {
  final List<MonitorEvent> events = [];

  @override
  void send(MonitorEvent event) {
    events.add(event);
  }

  @override
  Stream<void> get onConnect => const Stream.empty();

  @override
  Future<void> close() async {}
}

void main() {
  group('LevitMonitor logging', () {
    late _FakeTransport transport;

    setUp(() {
      transport = _FakeTransport();
      LevitMonitor.attach(transport: transport);
    });

    tearDown(() {
      LevitMonitor.detach();
    });

    test('LevitMonitor.log emits LogEvent with correct severity', () async {
      LevitMonitor.log('Hello Custom Log', level: Level.warning);
      await Future.delayed(Duration.zero);

      expect(transport.events.last, isA<LogEvent>());
      final event = transport.events.last as LogEvent;
      expect(event.level, Level.warning);
      expect(event.data, 'Hello Custom Log');
    });

    test('Helper method logTrace emits LogEvent with Level.trace', () async {
      LevitMonitor.logTrace('trace message');
      await Future.delayed(Duration.zero);

      expect(transport.events.last, isA<LogEvent>());
      final event = transport.events.last as LogEvent;
      expect(event.level, Level.trace);
      expect(event.data, 'trace message');
    });

    test('Helper method logDebug emits LogEvent with Level.debug', () async {
      LevitMonitor.logDebug('debug message');
      await Future.delayed(Duration.zero);

      expect(transport.events.last, isA<LogEvent>());
      final event = transport.events.last as LogEvent;
      expect(event.level, Level.debug);
      expect(event.data, 'debug message');
    });

    test('Helper method logInfo emits LogEvent with Level.info', () async {
      LevitMonitor.logInfo('info message');
      await Future.delayed(Duration.zero);

      expect(transport.events.last, isA<LogEvent>());
      final event = transport.events.last as LogEvent;
      expect(event.level, Level.info);
      expect(event.data, 'info message');
    });

    test('Helper method logWarning emits LogEvent with Level.warning', () async {
      LevitMonitor.logWarning('warning message');
      await Future.delayed(Duration.zero);

      expect(transport.events.last, isA<LogEvent>());
      final event = transport.events.last as LogEvent;
      expect(event.level, Level.warning);
      expect(event.data, 'warning message');
    });

    test('Helper method logError emits LogEvent with Level.error', () async {
      LevitMonitor.logError('error message');
      await Future.delayed(Duration.zero);

      expect(transport.events.last, isA<LogEvent>());
      final event = transport.events.last as LogEvent;
      expect(event.level, Level.error);
      expect(event.data, 'error message');
    });

    test('Helper method logFatal emits LogEvent with Level.fatal', () async {
      final error = StateError('bad');
      final stack = StackTrace.empty;
      LevitMonitor.logFatal('fatal message', error: error, stackTrace: stack);
      await Future.delayed(Duration.zero);

      expect(transport.events.last, isA<LogEvent>());
      final event = transport.events.last as LogEvent;
      expect(event.level, Level.fatal);
      expect(event.data, 'fatal message');
      expect(event.error, error);
      expect(event.stackTrace, stack);
    });

    test('Helper methods emit LogEvent with correct respective severities', () async {
      LevitMonitor.logTrace('trace message');
      await Future.delayed(Duration.zero);
      expect((transport.events.last as LogEvent).level, Level.trace);

      LevitMonitor.logDebug('debug message');
      await Future.delayed(Duration.zero);
      expect((transport.events.last as LogEvent).level, Level.debug);

      LevitMonitor.logInfo('info message');
      await Future.delayed(Duration.zero);
      expect((transport.events.last as LogEvent).level, Level.info);

      LevitMonitor.logWarning('warning message');
      await Future.delayed(Duration.zero);
      expect((transport.events.last as LogEvent).level, Level.warning);

      LevitMonitor.logError('error message');
      await Future.delayed(Duration.zero);
      expect((transport.events.last as LogEvent).level, Level.error);

      LevitMonitor.logFatal('fatal message');
      await Future.delayed(Duration.zero);
      expect((transport.events.last as LogEvent).level, Level.fatal);
    });

    test('Includes error and stack trace when provided', () async {
      final error = StateError('Something went wrong');
      final stack = StackTrace.current;

      LevitMonitor.logError('Failure', error: error, stackTrace: stack);
      await Future.delayed(Duration.zero);

      final event = transport.events.last as LogEvent;
      expect(event.error, error);
      expect(event.stackTrace, stack);
    });

    test('Includes error and stack trace when provided to helpers too', () async {
      final error = StateError('Something went wrong');
      final stack = StackTrace.fromString('helper trace');

      LevitMonitor.logTrace('trace', error: error, stackTrace: stack);
      await Future.delayed(Duration.zero);
      expect((transport.events.last as LogEvent).error, error);

      LevitMonitor.logDebug('debug', error: error, stackTrace: stack);
      await Future.delayed(Duration.zero);
      expect((transport.events.last as LogEvent).error, error);

      LevitMonitor.logInfo('info', error: error, stackTrace: stack);
      await Future.delayed(Duration.zero);
      expect((transport.events.last as LogEvent).error, error);

      LevitMonitor.logWarning('warning', error: error, stackTrace: stack);
      await Future.delayed(Duration.zero);
      expect((transport.events.last as LogEvent).error, error);

      LevitMonitor.logError('error msg', error: error, stackTrace: stack);
      await Future.delayed(Duration.zero);
      expect((transport.events.last as LogEvent).error, error);

      LevitMonitor.logFatal('fatal', error: error, stackTrace: stack);
      await Future.delayed(Duration.zero);
      expect((transport.events.last as LogEvent).error, error);
    });

    test('LevitMonitor.log does nothing when monitor is detached', () {
      // Detach the monitor first
      LevitMonitor.detach();
      final initialCount = transport.events.length;
      LevitMonitor.log('should be ignored');
      expect(transport.events.length, initialCount);
    });

    test('LevitMonitor.setLogLevel drops messages below minimum configured level', () async {
      final initialCount = transport.events.length;

      // Set level to warning
      LevitMonitor.setLogLevel(Level.warning);

      // These should be completely dropped
      LevitMonitor.logTrace('trace');
      LevitMonitor.logDebug('debug');
      LevitMonitor.logInfo('info');
      await Future.delayed(Duration.zero);
      expect(transport.events.length, initialCount);

      // These should be routed to the transport
      LevitMonitor.logWarning('warning');
      LevitMonitor.logError('error');
      LevitMonitor.logFatal('fatal');
      await Future.delayed(Duration.zero);

      expect(transport.events.length, initialCount + 3);
      final events = transport.events.sublist(initialCount);
      expect((events[0] as LogEvent).level, Level.warning);
      expect((events[1] as LogEvent).level, Level.error);
      expect((events[2] as LogEvent).level, Level.fatal);

      // Reset
      LevitMonitor.setLogLevel(Level.all);
    });

    test('LevitMonitor.logLevel retrieves current configured log level', () {
      LevitMonitor.setLogLevel(Level.error);
      expect(LevitMonitor.logLevel, Level.error);

      // Reset
      LevitMonitor.setLogLevel(Level.all);
      expect(LevitMonitor.logLevel, Level.all);
    });
  });
}
