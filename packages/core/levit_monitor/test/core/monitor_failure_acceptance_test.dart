import 'dart:async';
import 'package:levit/levit.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:logger/logger.dart' as logger;
import 'package:test/test.dart';

class Sink extends LevitTransport {
  Sink({this.failure});
  final Object? failure;
  final events = <MonitorEvent>[];
  late final connection = StreamController<void>(
    onCancel: () async {
      if (failure != null) throw failure!;
    },
  );
  @override
  Stream<void> get onConnect => connection.stream;
  @override
  int get droppedEvents => 2;
  @override
  void send(MonitorEvent event) => events.add(event);
  @override
  Future<void> flush() async {
    if (failure != null) throw failure!;
  }

  @override
  Future<void> close() => connection.close();
}

class BadMetadata extends LxVar<int> {
  BadMetadata() : super(0);
  @override
  String? get name => throw StateError('metadata');
}

class Printer extends logger.LogPrinter {
  final levels = <logger.Level>[];
  @override
  List<String> log(logger.LogEvent event) {
    levels.add(event.level);
    return [];
  }
}

LevitEventEnvelope envelope(
  String type, [
  Map<String, dynamic> fields = const {},
]) => LevitEventEnvelope({
  'sessionId': 'test',
  'seq': 1,
  'timestamp': DateTime(2026).toIso8601String(),
  'type': type,
  'category': 'state',
  ...fields,
});

void main() {
  tearDown(() async {
    try {
      await LevitMonitor.detach();
    } catch (_) {}
  });

  test('monitor validates bounds and rejects updates after close', () async {
    expect(() => LevitMonitorMiddleware(maxPendingEvents: 0), throwsRangeError);
    final sink = Sink();
    final monitor = LevitMonitorMiddleware(transport: sink)..enable();
    final value = 1.lx;
    expect(monitor.pendingEvents, 1);
    await monitor.flush();
    await monitor.close();
    expect(() => monitor.enable(), throwsStateError);
    await expectLater(
      monitor.updateTransport(transport: Sink()),
      throwsStateError,
    );
    await value.close();
    expect(LevitMonitor.snapshot, isNull);
    expect(LevitMonitor.history, isEmpty);
    expect(LevitMonitor.droppedEvents, 0);
  });

  test(
    'serialization and transport failures remain visible after replacement',
    () async {
      final value = BadMetadata();
      final failure = StateError('transport');
      final old = Sink(failure: failure);
      final next = Sink();
      final monitor = LevitMonitorMiddleware(transport: old)..enable();
      monitor.onReactiveMetadata(value);
      expect(monitor.droppedEvents, 3);
      old.connection.addError(StateError('connection'));
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        monitor.updateTransport(transport: next),
        throwsA(isA<LevitMonitorException>()),
      );
      expect(next.events.single.toJson()['type'], 'snapshot');
      await expectLater(monitor.close(), throwsA(isA<LevitMonitorException>()));
      expect(
        LevitMonitorException([AsyncError(failure, null)]).toString(),
        contains('1 recorded failures'),
      );
      await value.close();
    },
  );

  test(
    'multi-transport drop totals and disabled subscription failures are retained',
    () async {
      final sinks = [Sink(), Sink()];
      final multi = MultiTransport(sinks);
      expect(multi.droppedEvents, 4);
      final failed = Sink(failure: StateError('cancel'));
      final monitor = LevitMonitorMiddleware(transport: failed)..enable();
      monitor.disable();
      await expectLater(monitor.close(), throwsA(isA<LevitMonitorException>()));
    },
  );

  test(
    'snapshots bound task owners, restore trees, and redact metadata transitions',
    () {
      final snapshot = StateSnapshot();
      for (var i = 0; i < 257; i++) {
        snapshot.applyEnvelope(
          envelope('custom', {
            'namespace': 'levit.tasks',
            'name': 'tree',
            'attributes': {
              'ownerPath': 'owner$i',
              'tree': {'runningCount': i},
            },
          }),
        );
      }
      expect(snapshot.taskTrees.length, 256);
      expect(snapshot.taskTrees.containsKey('owner0'), isFalse);
      final restored = StateSnapshot()
        ..applyEnvelope(envelope('snapshot', {'state': snapshot.toJson()}));
      expect(restored.taskTrees, snapshot.taskTrees);
      restored.applyEnvelope(
        envelope('reactive_init', {
          'reactiveId': '1',
          'initialValue': 'secret',
          'valueType': 'String',
        }),
      );
      restored.applyEnvelope(
        envelope('reactive_metadata', {'reactiveId': '1', 'isSensitive': true}),
      );
      expect(restored.variables[1]!.value, isNot('secret'));
      expect(envelope('snapshot').category, 'state');
    },
  );

  test(
    'frozen events keep console severity and configured overrides',
    () async {
      final printer = Printer();
      final transport = ConsoleTransport(printer: printer);
      final types = <String, logger.Level>{
        'state_change': logger.Level.trace,
        'batch': logger.Level.debug,
        'reactive_init': logger.Level.debug,
        'reactive_dispose': logger.Level.debug,
        'graph_change': logger.Level.debug,
        'di_register': logger.Level.info,
        'di_resolve': logger.Level.debug,
        'di_delete': logger.Level.info,
        'di_instance_create': logger.Level.debug,
        'di_instance_init': logger.Level.debug,
        'listener_add': logger.Level.debug,
        'listener_remove': logger.Level.debug,
        'reactive_error': logger.Level.error,
        'unknown': logger.Level.debug,
      };
      for (final entry in types.entries) {
        transport.send(FrozenMonitorEvent(envelope(entry.key)));
        expect(printer.levels.last, entry.value, reason: entry.key);
      }
      transport.send(FrozenMonitorEvent(envelope('log', {'level': 'warning'})));
      expect(printer.levels.last, logger.Level.warning);
      transport.send(
        FrozenMonitorEvent(envelope('log', {'level': 'future-level'})),
      );
      expect(printer.levels.last, logger.Level.info);
      await transport.close();
      final overridden = ConsoleTransport(
        printer: printer,
        levelOverrides: const LevitLogLevelConfig(
          stateChange: LevitLogLevel.error,
        ),
      );
      overridden.send(FrozenMonitorEvent(envelope('state_change')));
      expect(printer.levels.last, logger.Level.error);
      await overridden.close();
    },
  );
}
