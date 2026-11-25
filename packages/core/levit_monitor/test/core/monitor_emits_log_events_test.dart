import 'package:levit_monitor/levit_monitor.dart';
import 'package:logger/logger.dart' hide LogEvent;
import 'package:test/test.dart';

class _FakeTransport extends LevitTransport {
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

    setUp(() async {
      transport = _FakeTransport();
      await LevitMonitor.attach(transport: transport);
    });

    tearDown(() async {
      await LevitMonitor.detach();
    });

    test('LevitMonitor.log emits LogEvent with correct severity', () async {
      LevitMonitor.log('Hello Custom Log', level: Level.warning);
      await Future.delayed(Duration.zero);

      expect(transport.events.last, isA<FrozenMonitorEvent>());
      final event = transport.events.last;
      expect(event.toJson()['level'], Level.warning.name);
      expect(event.toJson()['data'], 'Hello Custom Log');
    });

    test('Helper method logTrace emits LogEvent with Level.trace', () async {
      LevitMonitor.logTrace('trace message');
      await Future.delayed(Duration.zero);

      expect(transport.events.last, isA<FrozenMonitorEvent>());
      final event = transport.events.last;
      expect(event.toJson()['level'], Level.trace.name);
      expect(event.toJson()['data'], 'trace message');
    });

    test('Helper method logDebug emits LogEvent with Level.debug', () async {
      LevitMonitor.logDebug('debug message');
      await Future.delayed(Duration.zero);

      expect(transport.events.last, isA<FrozenMonitorEvent>());
      final event = transport.events.last;
      expect(event.toJson()['level'], Level.debug.name);
      expect(event.toJson()['data'], 'debug message');
    });

    test('Helper method logInfo emits LogEvent with Level.info', () async {
      LevitMonitor.logInfo('info message');
      await Future.delayed(Duration.zero);

      expect(transport.events.last, isA<FrozenMonitorEvent>());
      final event = transport.events.last;
      expect(event.toJson()['level'], Level.info.name);
      expect(event.toJson()['data'], 'info message');
    });

    test(
      'Helper method logWarning emits LogEvent with Level.warning',
      () async {
        LevitMonitor.logWarning('warning message');
        await Future.delayed(Duration.zero);

        expect(transport.events.last, isA<FrozenMonitorEvent>());
        final event = transport.events.last;
        expect(event.toJson()['level'], Level.warning.name);
        expect(event.toJson()['data'], 'warning message');
      },
    );

    test('Helper method logError emits LogEvent with Level.error', () async {
      LevitMonitor.logError('error message');
      await Future.delayed(Duration.zero);

      expect(transport.events.last, isA<FrozenMonitorEvent>());
      final event = transport.events.last;
      expect(event.toJson()['level'], Level.error.name);
      expect(event.toJson()['data'], 'error message');
    });

    test('Helper method logFatal emits LogEvent with Level.fatal', () async {
      final error = StateError('bad');
      final stack = StackTrace.empty;
      LevitMonitor.logFatal('fatal message', error: error, stackTrace: stack);
      await Future.delayed(Duration.zero);

      expect(transport.events.last, isA<FrozenMonitorEvent>());
      final event = transport.events.last;
      expect(event.toJson()['level'], Level.fatal.name);
      expect(event.toJson()['data'], 'fatal message');
      expect(event.toJson()['error'], error.toString());
      expect(event.toJson()['stackTrace'], stack.toString());
    });

    test(
      'Helper methods emit LogEvent with correct respective severities',
      () async {
        LevitMonitor.logTrace('trace message');
        await Future.delayed(Duration.zero);
        expect(transport.events.last.toJson()['level'], Level.trace.name);

        LevitMonitor.logDebug('debug message');
        await Future.delayed(Duration.zero);
        expect(transport.events.last.toJson()['level'], Level.debug.name);

        LevitMonitor.logInfo('info message');
        await Future.delayed(Duration.zero);
        expect(transport.events.last.toJson()['level'], Level.info.name);

        LevitMonitor.logWarning('warning message');
        await Future.delayed(Duration.zero);
        expect(transport.events.last.toJson()['level'], Level.warning.name);

        LevitMonitor.logError('error message');
        await Future.delayed(Duration.zero);
        expect(transport.events.last.toJson()['level'], Level.error.name);

        LevitMonitor.logFatal('fatal message');
        await Future.delayed(Duration.zero);
        expect(transport.events.last.toJson()['level'], Level.fatal.name);
      },
    );

    test('Includes error and stack trace when provided', () async {
      final error = StateError('Something went wrong');
      final stack = StackTrace.current;

      LevitMonitor.logError('Failure', error: error, stackTrace: stack);
      await Future.delayed(Duration.zero);

      final event = transport.events.last;
      expect(event.toJson()['error'], error.toString());
      expect(event.toJson()['stackTrace'], stack.toString());
    });

    test(
      'Includes error and stack trace when provided to helpers too',
      () async {
        final error = StateError('Something went wrong');
        final stack = StackTrace.fromString('helper trace');

        LevitMonitor.logTrace('trace', error: error, stackTrace: stack);
        await Future.delayed(Duration.zero);
        expect(transport.events.last.toJson()['error'], error.toString());

        LevitMonitor.logDebug('debug', error: error, stackTrace: stack);
        await Future.delayed(Duration.zero);
        expect(transport.events.last.toJson()['error'], error.toString());

        LevitMonitor.logInfo('info', error: error, stackTrace: stack);
        await Future.delayed(Duration.zero);
        expect(transport.events.last.toJson()['error'], error.toString());

        LevitMonitor.logWarning('warning', error: error, stackTrace: stack);
        await Future.delayed(Duration.zero);
        expect(transport.events.last.toJson()['error'], error.toString());

        LevitMonitor.logError('error msg', error: error, stackTrace: stack);
        await Future.delayed(Duration.zero);
        expect(transport.events.last.toJson()['error'], error.toString());

        LevitMonitor.logFatal('fatal', error: error, stackTrace: stack);
        await Future.delayed(Duration.zero);
        expect(transport.events.last.toJson()['error'], error.toString());
      },
    );

    test('LevitMonitor.log does nothing when monitor is detached', () async {
      // Detach the monitor first
      await LevitMonitor.detach();
      final initialCount = transport.events.length;
      LevitMonitor.log('should be ignored');
      expect(transport.events.length, initialCount);
    });

    test(
      'LevitMonitor.setLogLevel drops messages below minimum configured level',
      () async {
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
        expect(events[0].toJson()['level'], Level.warning.name);
        expect(events[1].toJson()['level'], Level.error.name);
        expect(events[2].toJson()['level'], Level.fatal.name);

        // Reset
        LevitMonitor.setLogLevel(Level.all);
      },
    );

    test('LevitMonitor.logLevel retrieves current configured log level', () {
      LevitMonitor.setLogLevel(Level.error);
      expect(LevitMonitor.logLevel, Level.error);

      // Reset
      LevitMonitor.setLogLevel(Level.all);
      expect(LevitMonitor.logLevel, Level.all);
    });
  });
}
