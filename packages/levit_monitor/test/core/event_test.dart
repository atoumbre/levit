import 'package:test/test.dart';
import 'package:levit_monitor/src/core/event.dart';
import 'package:levit_dart/levit_dart.dart';

void main() {
  group('MonitorEvent Hierarchy', () {
    test('StateChangeEvent serializes common and specific fields', () {
      final reactive = 0.lx.named('counter');
      final change = LevitStateChange<int>(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 0,
        newValue: 1,
      );

      final event = StateChangeEvent(
        sessionId: 'test-session',
        reactive: reactive,
        change: change,
      );

      final json = event.toJson();
      expect(json['type'], 'state_change');
      expect(json['sessionId'], 'test-session');
      expect(json['name'], 'counter');
      expect(json['oldValue'], '0');
      expect(json['newValue'], '1');
      expect(json['isBatch'], false);
    });

    test('BatchEvent serializes all entries', () {
      final r1 = 0.lx.named('r1');
      final r2 = 10.lx.named('r2');

      final batchChange = LevitStateBatchChange(
        [
          (
            r1,
            LevitStateChange(
                timestamp: DateTime.now(),
                valueType: int,
                oldValue: 0,
                newValue: 1)
          ),
          (
            r2,
            LevitStateChange(
                timestamp: DateTime.now(),
                valueType: int,
                oldValue: 10,
                newValue: 11)
          ),
        ],
        batchId: 123,
      );

      final event = BatchEvent(sessionId: 'test-session', change: batchChange);
      final json = event.toJson();

      expect(json['type'], 'batch');
      expect(json['batchId'], 123);
      expect(json['count'], 2);
      expect(json['entries'], hasLength(2));
      expect(json['entries'][0]['name'], 'r1');
      expect(json['entries'][1]['name'], 'r2');
    });

    test('DIRegisterEvent serializes DI metadata', () {
      final info = LevitBindingEntry(
        builder: () => 42,
        isLazy: true,
        permanent: true,
      );

      final event = DIRegisterEvent(
        sessionId: 'test-session',
        scopeId: 1,
        scopeName: 'root',
        key: 'int',
        info: info,
        source: 'test-code',
      );

      final json = event.toJson();
      expect(json['type'], 'di_register');
      expect(json['scopeName'], 'root');
      expect(json['isLazy'], true);
      expect(json['permanent'], true);
      expect(json['source'], 'test-code');
    });

    test('_stringify handles null and unprintable objects', () {
      final event = ReactiveInitEvent(
        sessionId: 's',
        reactive: _Unprintable().lx.named('bad'),
      );

      final json = event.toJson();
      expect(json['initialValue'], '<unprintable>');
    });

    test('ReactiveInitEvent with null value', () {
      final reactive = null.lxNullable.named('nullable');
      final event = ReactiveInitEvent(
        sessionId: 'test',
        reactive: reactive,
      );

      final json = event.toJson();
      expect(json['type'], 'reactive_init');
      expect(json['name'], 'nullable');
      expect(json['initialValue'], isNull);
    });

    test('ReactiveDisposeEvent serialization', () {
      final reactive = 0.lx.named('disposed');
      final event = ReactiveDisposeEvent(
        sessionId: 'test',
        reactive: reactive,
      );

      final json = event.toJson();
      expect(json['type'], 'reactive_dispose');
      expect(json['name'], 'disposed');
    });

    test('GraphChangeEvent serialization', () {
      final dep1 = 0.lx.named('dep1');
      final dep2 = 1.lx.named('dep2');
      final computed = (() => dep1.value + dep2.value).lx.named('sum');

      final event = GraphChangeEvent(
        sessionId: 'test',
        reactive: computed,
        dependencies: [dep1, dep2],
      );

      final json = event.toJson();
      expect(json['type'], 'graph_change');
      expect(json['dependencies'], hasLength(2));
      expect(json['dependencies'][0]['name'], 'dep1');
      expect(json['dependencies'][1]['name'], 'dep2');
    });

    test('DIResolveEvent with instance serialization', () {
      final info = LevitBindingEntry(
        instance: 'resolved_value',
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

      final json = event.toJson();
      expect(json['type'], 'di_resolve');
      expect(json['instance'], 'resolved_value');
      expect(json['source'], 'find');
    });

    test('DIDeleteEvent serialization', () {
      final info = LevitBindingEntry(
        instance: 'deleted',
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

      final json = event.toJson();
      expect(json['type'], 'di_delete');
      expect(json['source'], 'delete');
    });

    test('DIInstanceCreateEvent serialization', () {
      final info = LevitBindingEntry(
        builder: () => 'created',
        isLazy: false,
        permanent: false,
      );

      final event = DIInstanceCreateEvent(
        sessionId: 'test',
        scopeId: 1,
        scopeName: 'root',
        key: 'String_created',
        info: info,
      );

      final json = event.toJson();
      expect(json['type'], 'di_instance_create');
      expect(json['isLazy'], false);
    });

    test('DIInstanceInitEvent serialization', () {
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

      final json = event.toJson();
      expect(json['type'], 'di_instance_init');
      expect(json['instance'], 'initialized');
    });

    test('Event sequence numbers increment', () {
      final r1 = 0.lx;
      final event1 = ReactiveInitEvent(sessionId: 'test', reactive: r1);
      final event2 = ReactiveInitEvent(sessionId: 'test', reactive: r1);

      expect(event2.seq, greaterThan(event1.seq));
    });

    test('Event includes timestamp', () {
      final reactive = 0.lx;
      final event = ReactiveInitEvent(sessionId: 'test', reactive: reactive);
      final json = event.toJson();

      expect(json['timestamp'], isA<String>());
      expect(DateTime.parse(json['timestamp']), isA<DateTime>());
    });
  });
}

class _Unprintable {
  @override
  String toString() => throw UnimplementedError('Cannot print me');
}
