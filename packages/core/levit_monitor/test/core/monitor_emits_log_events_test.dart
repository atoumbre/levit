import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

class _FakeTransport extends LevitTransport {
  final List<LevitMonitorEvent> events = [];

  @override
  void send(LevitMonitorEvent event) {
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

    test(
      'LevitMonitor.log emits LevitLogEvent with correct severity',
      () async {
        LevitMonitor.log('Hello Custom Log', level: LevitLogLevel.warning);
        await Future.delayed(Duration.zero);

        expect(transport.events.last, isA<LevitFrozenMonitorEvent>());
        final event = transport.events.last;
        expect(event.toJson()['level'], LevitLogLevel.warning.name);
        expect(event.toJson()['data'], 'Hello Custom Log');
      },
    );

    test(
      'Helper method logTrace emits LevitLogEvent with LevitLogLevel.trace',
      () async {
        LevitMonitor.logTrace('trace message');
        await Future.delayed(Duration.zero);

        expect(transport.events.last, isA<LevitFrozenMonitorEvent>());
        final event = transport.events.last;
        expect(event.toJson()['level'], LevitLogLevel.trace.name);
        expect(event.toJson()['data'], 'trace message');
      },
    );

    test(
      'Helper method logDebug emits LevitLogEvent with LevitLogLevel.debug',
      () async {
        LevitMonitor.logDebug('debug message');
        await Future.delayed(Duration.zero);

        expect(transport.events.last, isA<LevitFrozenMonitorEvent>());
        final event = transport.events.last;
        expect(event.toJson()['level'], LevitLogLevel.debug.name);
        expect(event.toJson()['data'], 'debug message');
      },
    );

    test(
      'Helper method logInfo emits LevitLogEvent with LevitLogLevel.info',
      () async {
        LevitMonitor.logInfo('info message');
        await Future.delayed(Duration.zero);

        expect(transport.events.last, isA<LevitFrozenMonitorEvent>());
        final event = transport.events.last;
        expect(event.toJson()['level'], LevitLogLevel.info.name);
        expect(event.toJson()['data'], 'info message');
      },
    );

    test(
      'Helper method logWarning emits LevitLogEvent with LevitLogLevel.warning',
      () async {
        LevitMonitor.logWarning('warning message');
        await Future.delayed(Duration.zero);

        expect(transport.events.last, isA<LevitFrozenMonitorEvent>());
        final event = transport.events.last;
        expect(event.toJson()['level'], LevitLogLevel.warning.name);
        expect(event.toJson()['data'], 'warning message');
      },
    );

    test(
      'Helper method logError emits LevitLogEvent with LevitLogLevel.error',
      () async {
        LevitMonitor.logError('error message');
        await Future.delayed(Duration.zero);

        expect(transport.events.last, isA<LevitFrozenMonitorEvent>());
        final event = transport.events.last;
        expect(event.toJson()['level'], LevitLogLevel.error.name);
        expect(event.toJson()['data'], 'error message');
      },
    );

    test(
      'Helper method logFatal emits LevitLogEvent with LevitLogLevel.fatal',
      () async {
        final error = StateError('bad');
        final stack = StackTrace.empty;
        LevitMonitor.logFatal('fatal message', error: error, stackTrace: stack);
        await Future.delayed(Duration.zero);

        expect(transport.events.last, isA<LevitFrozenMonitorEvent>());
        final event = transport.events.last;
        expect(event.toJson()['level'], LevitLogLevel.fatal.name);
        expect(event.toJson()['data'], 'fatal message');
        expect(event.toJson()['error'], error.toString());
        expect(event.toJson()['stackTrace'], stack.toString());
      },
    );

    test(
      'Helper methods emit LevitLogEvent with correct respective severities',
      () async {
        LevitMonitor.logTrace('trace message');
        await Future.delayed(Duration.zero);
        expect(
          transport.events.last.toJson()['level'],
          LevitLogLevel.trace.name,
        );

        LevitMonitor.logDebug('debug message');
        await Future.delayed(Duration.zero);
        expect(
          transport.events.last.toJson()['level'],
          LevitLogLevel.debug.name,
        );

        LevitMonitor.logInfo('info message');
        await Future.delayed(Duration.zero);
        expect(
          transport.events.last.toJson()['level'],
          LevitLogLevel.info.name,
        );

        LevitMonitor.logWarning('warning message');
        await Future.delayed(Duration.zero);
        expect(
          transport.events.last.toJson()['level'],
          LevitLogLevel.warning.name,
        );

        LevitMonitor.logError('error message');
        await Future.delayed(Duration.zero);
        expect(
          transport.events.last.toJson()['level'],
          LevitLogLevel.error.name,
        );

        LevitMonitor.logFatal('fatal message');
        await Future.delayed(Duration.zero);
        expect(
          transport.events.last.toJson()['level'],
          LevitLogLevel.fatal.name,
        );
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
        LevitMonitor.setLogLevel(LevitLogLevel.warning);

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
        expect(events[0].toJson()['level'], LevitLogLevel.warning.name);
        expect(events[1].toJson()['level'], LevitLogLevel.error.name);
        expect(events[2].toJson()['level'], LevitLogLevel.fatal.name);

        // Reset
        LevitMonitor.setLogLevel(LevitLogLevel.all);
      },
    );

    test('LevitMonitor.logLevel retrieves current configured log level', () {
      LevitMonitor.setLogLevel(LevitLogLevel.error);
      expect(LevitMonitor.logLevel, LevitLogLevel.error);

      // Reset
      LevitMonitor.setLogLevel(LevitLogLevel.all);
      expect(LevitMonitor.logLevel, LevitLogLevel.all);
    });
  });
}
