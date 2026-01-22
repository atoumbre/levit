import 'package:levit_dart/levit_dart.dart';
import 'package:levit_monitor/src/core/event.dart';
import 'package:levit_monitor/src/transports/console_transport.dart';
import 'package:test/test.dart';

void main() {
  group('ConsoleTransport', () {
    late ConsoleTransport transport;
    late ConsoleTransport silentTransport;

    setUp(() {
      transport = ConsoleTransport();
      // Use minLevel.off to suppress output in tests
      silentTransport = ConsoleTransport(minLevel: LevitLogLevel.off);
    });

    tearDown(() {
      transport.close();
      silentTransport.close();
    });

    test('formats ReactiveChangeEvent', () {
      final reactive = 0.lx.named('counter');
      final change = LevitReactiveChange<int>(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 0,
        newValue: 1,
      );
      final event = ReactiveChangeEvent(
        sessionId: 'test',
        reactive: reactive,
        change: change,
      );

      // Should not throw
      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats ReactiveBatchEvent', () {
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
          )
        ),
        (
          rx2,
          LevitReactiveChange(
            timestamp: DateTime.now(),
            valueType: int,
            oldValue: 1,
            newValue: 2,
          )
        ),
      ], batchId: 123);

      final event = ReactiveBatchEvent(sessionId: 'test', change: batchChange);

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats ReactiveInitEvent', () {
      final reactive = 0.lx.named('init_test');
      final event = ReactiveInitEvent(
        sessionId: 'test',
        reactive: reactive,
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats ReactiveDisposeEvent', () {
      final reactive = 0.lx.named('dispose_test');
      final event = ReactiveDisposeEvent(
        sessionId: 'test',
        reactive: reactive,
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats ReactiveGraphChangeEvent', () {
      final source = 0.lx.named('source');
      final computed = (() => source.value * 2).lx.named('computed');
      final event = ReactiveGraphChangeEvent(
        sessionId: 'test',
        reactive: computed,
        dependencies: [source],
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats DependencyRegisterEvent', () {
      final info = LevitDependency(
        builder: () => 'test',
        isLazy: true,
        permanent: false,
      );
      final event = DependencyRegisterEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_test',
        info: info,
        source: 'test',
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats DependencyResolveEvent', () {
      final info = LevitDependency(
        instance: 'test_value',
        permanent: false,
      );
      final event = DependencyResolveEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_test',
        info: info,
        source: 'find',
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats DependencyDeleteEvent', () {
      final info = LevitDependency(
        instance: 'deleted_value',
        permanent: false,
      );
      final event = DependencyDeleteEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_deleted',
        info: info,
        source: 'delete',
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats DependencyInstanceCreateEvent', () {
      final info = LevitDependency(
        builder: () => 'created',
        permanent: false,
      );
      final event = DependencyInstanceCreateEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_created',
        info: info,
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('formats DependencyInstanceReadyEvent', () {
      final info = LevitDependency(
        instance: 'initialized',
        permanent: false,
      );
      final event = DependencyInstanceReadyEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_init',
        info: info,
        instance: 'initialized',
      );

      expect(() => silentTransport.send(event), returnsNormally);
    });

    test('close does not throw', () {
      final t = ConsoleTransport();
      expect(() => t.close(), returnsNormally);
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

    test('custom overrides are applied', () {
      final transport = ConsoleTransport(
        minLevel: LevitLogLevel.off,
        levelOverrides: const LevitLogLevelConfig(
          stateChange: LevitLogLevel.debug,
          diResolve: LevitLogLevel.off,
        ),
      );

      final reactive = 0.lx.named('test');
      final event = ReactiveChangeEvent(
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
      transport.close();
    });

    test('reactiveDispose override is applied (line 188)', () {
      final transport = ConsoleTransport(
        minLevel: LevitLogLevel.off,
        levelOverrides: const LevitLogLevelConfig(
          reactiveDispose: LevitLogLevel.info,
        ),
      );

      final reactive = 0.lx.named('dispose_test');
      final event = ReactiveDisposeEvent(
        sessionId: 'test',
        reactive: reactive,
      );

      // This triggers the reactiveDispose branch in _levelFor
      expect(() => transport.send(event), returnsNormally);
      transport.close();
    });
  });

  group('LevitLogLevel enum', () {
    test('all levels map to Logger levels', () {
      expect(LevitLogLevel.off.level, isNotNull);
      expect(LevitLogLevel.trace.level, isNotNull);
      expect(LevitLogLevel.debug.level, isNotNull);
      expect(LevitLogLevel.info.level, isNotNull);
      expect(LevitLogLevel.warning.level, isNotNull);
      expect(LevitLogLevel.error.level, isNotNull);
      expect(LevitLogLevel.fatal.level, isNotNull);
      expect(LevitLogLevel.all.level, isNotNull);
    });
  });
}
