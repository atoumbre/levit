import 'package:levit_dart/levit_dart.dart';
import 'package:levit_monitor/src/core/event.dart';
import 'package:levit_monitor/src/transports/console_transport.dart';
import 'package:test/test.dart';

void main() {
  group('ConsoleTransport', () {
    late ConsoleTransport transport;
    late ConsoleTransport noColorTransport;

    setUp(() {
      transport = const ConsoleTransport(useColors: true, prefix: '[TEST]');
      noColorTransport = const ConsoleTransport(useColors: false);
    });

    test('formats StateChangeEvent with colors', () {
      final reactive = 0.lx.named('counter');
      final change = LevitStateChange<int>(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 0,
        newValue: 1,
      );
      final event = StateChangeEvent(
        sessionId: 'test',
        reactive: reactive,
        change: change,
      );

      // Should not throw
      expect(() => transport.send(event), returnsNormally);
    });

    test('formats StateChangeEvent without colors', () {
      final reactive = 0.lx.named('counter');
      final change = LevitStateChange<int>(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 0,
        newValue: 1,
      );
      final event = StateChangeEvent(
        sessionId: 'test',
        reactive: reactive,
        change: change,
      );

      expect(() => noColorTransport.send(event), returnsNormally);
    });

    test('formats BatchEvent', () {
      final rx1 = 0.lx;
      final rx2 = 1.lx;
      final batchChange = LevitStateBatchChange([
        (
          rx1,
          LevitStateChange(
            timestamp: DateTime.now(),
            valueType: int,
            oldValue: 0,
            newValue: 1,
          )
        ),
        (
          rx2,
          LevitStateChange(
            timestamp: DateTime.now(),
            valueType: int,
            oldValue: 1,
            newValue: 2,
          )
        ),
      ], batchId: 123);

      final event = BatchEvent(sessionId: 'test', change: batchChange);

      expect(() => transport.send(event), returnsNormally);
    });

    test('formats ReactiveInitEvent', () {
      final reactive = 0.lx.named('init_test');
      final event = ReactiveInitEvent(
        sessionId: 'test',
        reactive: reactive,
      );

      expect(() => transport.send(event), returnsNormally);
    });

    test('formats ReactiveDisposeEvent', () {
      final reactive = 0.lx.named('dispose_test');
      final event = ReactiveDisposeEvent(
        sessionId: 'test',
        reactive: reactive,
      );

      expect(() => transport.send(event), returnsNormally);
    });

    test('formats GraphChangeEvent', () {
      final source = 0.lx.named('source');
      final computed = (() => source.value * 2).lx.named('computed');
      final event = GraphChangeEvent(
        sessionId: 'test',
        reactive: computed,
        dependencies: [source],
      );

      expect(() => transport.send(event), returnsNormally);
    });

    test('formats DIRegisterEvent', () {
      final info = LevitBindingEntry(
        builder: () => 'test',
        isLazy: true,
        permanent: false,
      );
      final event = DIRegisterEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_test',
        info: info,
        source: 'test',
      );

      expect(() => transport.send(event), returnsNormally);
    });

    test('formats DIResolveEvent', () {
      final info = LevitBindingEntry(
        instance: 'test_value',
        permanent: false,
      );
      final event = DIResolveEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_test',
        info: info,
        source: 'find',
      );

      expect(() => transport.send(event), returnsNormally);
    });

    test('formats DIDeleteEvent', () {
      final info = LevitBindingEntry(
        instance: 'deleted_value',
        permanent: false,
      );
      final event = DIDeleteEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_deleted',
        info: info,
        source: 'delete',
      );

      expect(() => transport.send(event), returnsNormally);
    });

    test('formats DIInstanceCreateEvent', () {
      final info = LevitBindingEntry(
        builder: () => 'created',
        permanent: false,
      );
      final event = DIInstanceCreateEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_created',
        info: info,
      );

      expect(() => transport.send(event), returnsNormally);
    });

    test('formats DIInstanceInitEvent', () {
      final info = LevitBindingEntry(
        instance: 'initialized',
        permanent: false,
      );
      final event = DIInstanceInitEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_init',
        info: info,
        instance: 'initialized',
      );

      expect(() => transport.send(event), returnsNormally);
    });

    test('close does nothing', () {
      expect(() => transport.close(), returnsNormally);
    });

    test('uses custom prefix', () {
      final customTransport = const ConsoleTransport(prefix: '[CUSTOM]');
      final reactive = 0.lx.named('test');
      final change = LevitStateChange<int>(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 0,
        newValue: 1,
      );
      final event = StateChangeEvent(
        sessionId: 'test',
        reactive: reactive,
        change: change,
      );

      expect(() => customTransport.send(event), returnsNormally);
    });
  });
}
