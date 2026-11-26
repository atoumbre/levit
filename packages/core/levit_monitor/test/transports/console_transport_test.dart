import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

void main() {
  group('LevitConsoleTransport', () {
    late LevitConsoleTransport transport;
    late LevitConsoleTransport silentTransport;

    setUp(() {
      transport = LevitConsoleTransport();
      // Use minLevel.off to suppress output in tests
      silentTransport = LevitConsoleTransport(minLevel: LevitLogLevel.off);
    });

    tearDown(() async {
      await transport.close();
      await silentTransport.close();
    });

    test('formats LevitReactiveChangeEvent', () {
      final reactive = 0.lx.named('counter');
      final change = LevitReactiveChange<int>(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 0,
        newValue: 1,
      );
      final event = LevitReactiveChangeEvent(
        sessionId: 'test',
        reactive: reactive,
        change: change,
      );

      // Should not throw
      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats LevitReactiveBatchEvent', () {
      final rx1 = 0.lx;
      final rx2 = 1.lx;
      final batchChange = LevitReactiveBatch([
        (
          rx1,
          LevitReactiveChange(
            timestamp: DateTime.now(),
            valueType: int,
            oldValue: 0,
            newValue: 1,
          ),
        ),
        (
          rx2,
          LevitReactiveChange(
            timestamp: DateTime.now(),
            valueType: int,
            oldValue: 1,
            newValue: 2,
          ),
        ),
      ], batchId: 123);

      final event = LevitReactiveBatchEvent(
        sessionId: 'test',
        change: batchChange,
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats LevitReactiveInitEvent', () {
      final reactive = 0.lx.named('init_test');
      final event = LevitReactiveInitEvent(
        sessionId: 'test',
        reactive: reactive,
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats LevitReactiveDisposeEvent', () {
      final reactive = 0.lx.named('dispose_test');
      final event = LevitReactiveDisposeEvent(
        sessionId: 'test',
        reactive: reactive,
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats LevitReactiveGraphChangeEvent', () {
      final source = 0.lx.named('source');
      final computed = (() => source.value * 2).lx.named('computed');
      final event = LevitReactiveGraphChangeEvent(
        sessionId: 'test',
        reactive: computed,
        dependencies: [source],
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats LevitDependencyRegisterEvent', () {
      final info = LevitDependency(
        builder: () => 'test',
        isLazy: true,
        permanent: false,
      );
      final event = LevitDependencyRegisterEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_test',
        info: info,
        source: 'test',
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats LevitDependencyResolveEvent', () {
      final info = LevitDependency(instance: 'test_value', permanent: false);
      final event = LevitDependencyResolveEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_test',
        info: info,
        source: 'find',
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats LevitDependencyDeleteEvent', () {
      final info = LevitDependency(instance: 'deleted_value', permanent: false);
      final event = LevitDependencyDeleteEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_deleted',
        info: info,
        source: 'delete',
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats LevitDependencyInstanceCreateEvent', () {
      final info = LevitDependency(builder: () => 'created', permanent: false);
      final event = LevitDependencyInstanceCreateEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_created',
        info: info,
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats LevitDependencyInstanceReadyEvent', () {
      final info = LevitDependency(instance: 'initialized', permanent: false);
      final event = LevitDependencyInstanceReadyEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_init',
        info: info,
        instance: 'initialized',
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats LevitLogEvent properly with error and stack trace', () {
      final event = LevitLogEvent(
        sessionId: 'test',
        level: LevitLogLevel.error,
        data: 'an error occurred',
        error: StateError('bad state'),
        stackTrace: StackTrace.fromString('stack frame 1'),
      );

      // We expect output to contain Error and Stack strings
      LevitMonitor.setObfuscator(null);
      final lines = <String>[];
      final t = LevitConsoleTransport(
        minLevel: LevitLogLevel.all,
        formatter: (_, message) => message,
        output: lines.add,
      );
      t.send(event);

      final output = lines.join('\n');
      expect(output, contains('LOG: an error occurred'));
      expect(output, contains('Error: Bad state: bad state'));
      expect(output, contains('Stack: \nstack frame 1'));
    });

    test('LevitLogEvent trace and debug levels are mapped correctly', () {
      final t = LevitConsoleTransport(minLevel: LevitLogLevel.all);

      final traceEvent = LevitLogEvent(
        sessionId: '1',
        level: LevitLogLevel.trace,
        data: 'trace',
      );
      final debugEvent = LevitLogEvent(
        sessionId: '1',
        level: LevitLogLevel.debug,
        data: 'debug',
      );

      expect(() => t.send(traceEvent), returnsNormally);
      expect(() => t.send(debugEvent), returnsNormally);
    });

    test(
      'supports plain formatting without colors or emojis and ignores sends after close',
      () async {
        final lines = <String>[];
        final t = LevitConsoleTransport(
          minLevel: LevitLogLevel.info,
          colors: false,
          includeEmojis: false,
          output: lines.add,
        );
        final event = LevitLogEvent(
          sessionId: 'test',
          level: LevitLogLevel.info,
          data: 'plain message',
        );
        t.send(event);
        expect(lines.single, '[INFO] LOG: plain message');

        await t.close();
        t.send(event);
        expect(lines.length, 1);
      },
    );

    test('close does not throw', () async {
      final t = LevitConsoleTransport();
      await expectLater(t.close(), completes);
    });

    test('obfuscates sensitive values in logged messages', () async {
      LevitMonitor.setObfuscator(null);
      final lines = <String>[];
      final t = LevitConsoleTransport(
        minLevel: LevitLogLevel.all,
        formatter: (_, message) => message,
        output: lines.add,
      );

      final reactive = 'sensitive-value'.lxVar(
        name: 'password',
        isSensitive: true,
      );

      t.send(LevitReactiveInitEvent(sessionId: 'test', reactive: reactive));
      t.send(
        LevitReactiveChangeEvent(
          sessionId: 'test',
          reactive: reactive,
          change: LevitReactiveChange<String>(
            timestamp: DateTime.now(),
            valueType: String,
            oldValue: 'sensitive-value',
            newValue: 'new-sensitive-value',
          ),
        ),
      );

      final output = lines.join('\n');
      expect(output, contains('***'));
      expect(output, isNot(contains('new-sensitive-value')));

      await t.close();
    });
  });

  group('LevitLogLevelConfig', () {
    test('default config allows null overrides', () {
      const config = LevitLogLevelConfig();
      expect(config.stateChange, isNull);
      expect(config.diRegister, isNull);
    });

    test('all config parameters can be set', () {
      // Using non-const to trigger runtime constructor execution for coverage (line 81)
      // ignore: prefer_const_constructors
      final config = LevitLogLevelConfig(
        stateChange: LevitLogLevel.trace,
        batch: LevitLogLevel.debug,
        reactiveInit: LevitLogLevel.debug,
        reactiveDispose: LevitLogLevel.debug,
        graphChange: LevitLogLevel.debug,
        diRegister: LevitLogLevel.info,
        diResolve: LevitLogLevel.debug,
        diDelete: LevitLogLevel.info,
        diCreate: LevitLogLevel.debug,
        diInit: LevitLogLevel.debug,
      );

      expect(config.stateChange, LevitLogLevel.trace);
      expect(config.batch, LevitLogLevel.debug);
      expect(config.reactiveInit, LevitLogLevel.debug);
      expect(config.reactiveDispose, LevitLogLevel.debug);
      expect(config.graphChange, LevitLogLevel.debug);
      expect(config.diRegister, LevitLogLevel.info);
      expect(config.diResolve, LevitLogLevel.debug);
      expect(config.diDelete, LevitLogLevel.info);
      expect(config.diCreate, LevitLogLevel.debug);
      expect(config.diInit, LevitLogLevel.debug);
    });

    test('custom overrides are applied', () async {
      final transport = LevitConsoleTransport(
        minLevel: LevitLogLevel.off,
        levelOverrides: const LevitLogLevelConfig(
          stateChange: LevitLogLevel.debug,
          diResolve: LevitLogLevel.off,
        ),
      );

      final reactive = 0.lx.named('test');
      final event = LevitReactiveChangeEvent(
        sessionId: 'test',
        reactive: reactive,
        change: LevitReactiveChange<int>(
          timestamp: DateTime.now(),
          valueType: int,
          oldValue: 0,
          newValue: 1,
        ),
      );

      expect(() => transport.send(event), returnsNormally);
      await transport.close();
    });

    test(
      'reactiveDispose overrides determine the console disposal message',
      () async {
        final transport = LevitConsoleTransport(
          minLevel: LevitLogLevel.off,
          levelOverrides: const LevitLogLevelConfig(
            reactiveDispose: LevitLogLevel.info,
          ),
        );

        final reactive = 0.lx.named('dispose_test');
        final event = LevitReactiveDisposeEvent(
          sessionId: 'test',
          reactive: reactive,
        );

        // This triggers the reactiveDispose branch in _levelFor
        expect(() => transport.send(event), returnsNormally);
        await transport.close();
      },
    );
  });

  group('LevitLogLevel enum', () {
    test('all levels define monotonic severity values', () {
      expect(LevitLogLevel.all.value, lessThan(LevitLogLevel.trace.value));
      expect(LevitLogLevel.trace.value, lessThan(LevitLogLevel.debug.value));
      expect(LevitLogLevel.debug.value, lessThan(LevitLogLevel.info.value));
      expect(LevitLogLevel.info.value, lessThan(LevitLogLevel.warning.value));
      expect(LevitLogLevel.warning.value, lessThan(LevitLogLevel.error.value));
      expect(LevitLogLevel.error.value, lessThan(LevitLogLevel.fatal.value));
      expect(LevitLogLevel.fatal.value, lessThan(LevitLogLevel.off.value));
    });
  });
}
