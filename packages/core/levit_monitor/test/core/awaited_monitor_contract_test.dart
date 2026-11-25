import 'dart:async';
import 'dart:convert';
import 'package:levit/levit.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import '../../example/task_adapter.dart';

void main() {
  tearDown(() async {
    try {
      await LevitMonitor.detach();
    } catch (_) {}
    LevitMonitor.setFilter(null);
  });
  test(
    'keyed membership stays redacted and lazy producers keep their owner',
    () async {
      final sink = _Sink();
      await LevitMonitor.attach(transport: sink, historyCapacity: 256);
      Levit.enableAutoLinking();
      const rawKey = 'member-private@example.com';
      final map = Lx.runWithOwner(
        'catalog-feature',
        () => LevitAsyncMap<String, int>((k, _) => 1, name: 'pages'),
      );
      try {
        final view = map.entry(rawKey);
        view.addListener(() {});
        await map.fetch(rawKey);
        await map.refresh(rawKey);
        await LevitMonitor.flush();
        for (final data in [
          sink.events.map((e) => e.toJson()).toList(),
          LevitMonitor.history.map((e) => e.toJson()).toList(),
          LevitMonitor.snapshot,
        ]) {
          final json = jsonEncode(data);
          expect(json, isNot(contains(rawKey)));
          expect(json, contains('catalog-feature'));
          expect(json, contains('pages['));
        }
      } finally {
        await map.close();
        Levit.disableAutoLinking();
      }
    },
  );
  test(
    'capture freezes redaction and nested payloads before queues and history',
    () async {
      final sink = _BlockedSink();
      await LevitMonitor.attach(transport: sink, historyCapacity: 10);
      final value = LxVar('secret', isSensitive: true);
      final nested = <String, Object?>{
        'values': [1],
      };
      LevitMonitor.emitCustomEvent(
        namespace: 'app',
        name: 'update',
        attributes: nested,
      );
      (nested['values'] as List).add(2);
      value.value = 'new-secret';
      value.isSensitive = false;
      sink.release.complete();
      await LevitMonitor.flush();
      final wire = jsonEncode(
        sink.events.map((event) => event.toJson()).toList(),
      );
      expect(wire, isNot(contains('new-secret')));
      expect(wire, isNot(contains('"secret"')));
      final event = sink.events.singleWhere(
        (event) => event.toJson()['type'] == 'custom',
      );
      expect(event.toJson()['attributes'], {
        'values': [1],
      });
      expect(
        () => (event.toJson()['attributes'] as Map)['leak'] = true,
        throwsUnsupportedError,
      );
      expect(
        jsonEncode(LevitMonitor.history.map((e) => e.toJson()).toList()),
        isNot(contains('new-secret')),
      );
      expect(jsonEncode(LevitMonitor.snapshot), isNot(contains('new-secret')));
      await value.close();
    },
  );
  test(
    'history defaults off and bounded queues report dropped events',
    () async {
      final sink = _BlockedSink();
      await LevitMonitor.attach(transport: sink, maxPendingEvents: 2);
      for (var i = 0; i < 10; i++) {
        LevitMonitor.log(i);
      }
      expect(LevitMonitor.history, isEmpty);
      expect(LevitMonitor.droppedEvents, 8);
      sink.release.complete();
      await LevitMonitor.flush();
      expect(sink.events.length, 2);
      await LevitMonitor.attach(transport: _Sink(), historyCapacity: 2);
      for (var i = 0; i < 4; i++) {
        LevitMonitor.log(i);
      }
      await LevitMonitor.flush();
      expect(LevitMonitor.history.length, 2);
      expect(LevitMonitor.snapshot!['droppedHistoryEvents'], 2);
      expect(LevitMonitor.snapshot!['historyComplete'], isFalse);
    },
  );
  test(
    'replacement and detach await accepted sends and transport cleanup',
    () async {
      final first = _BlockedSink();
      final second = _Sink();
      await LevitMonitor.attach(transport: first);
      LevitMonitor.log('first');
      var replaced = false;
      final replacement = LevitMonitor.attach(
        transport: second,
      ).then((_) => replaced = true);
      await Future<void>.delayed(Duration.zero);
      expect(replaced, isFalse);
      expect(first.closed, isFalse);
      first.release.complete();
      await replacement;
      expect(first.closed, isTrue);
      LevitMonitor.log('second');
      await LevitMonitor.detach();
      expect(second.events.single.toJson()['data'], 'second');
      expect(second.closed, isTrue);
    },
  );
  test('failures propagate after all sinks close', () async {
    final good = _Sink();
    final bad = _FailingSink();
    await LevitMonitor.attach(transports: [bad, good]);
    LevitMonitor.log('record');
    await expectLater(
      LevitMonitor.detach(),
      throwsA(isA<LevitMonitorException>()),
    );
    expect(good.events.length, 1);
    expect(good.closed, isTrue);
    expect(bad.closed, isTrue);
  });
  test(
    'transport replacement installs the new sink after failed old cleanup',
    () async {
      final old = _FailingSink();
      final next = _Sink();
      final monitor = LevitMonitorMiddleware(transport: old)..enable();
      LevitMonitor.log('not a global attachment');
      final value = 1.lx;
      await expectLater(
        monitor.updateTransport(transport: next),
        throwsA(isA<LevitMonitorException>()),
      );
      expect(old.closed, isTrue);
      expect(identical(monitor.transport, next), isTrue);
      expect(
        next.events.any((event) => event.toJson()['type'] == 'snapshot'),
        isTrue,
      );
      await expectLater(monitor.close(), throwsA(isA<LevitMonitorException>()));
      expect(next.closed, isTrue);
      await value.close();
    },
  );
  test(
    'update attribution and optional task adapter do not retain owned work',
    () async {
      final sink = _Sink();
      await LevitMonitor.attach(transport: sink, includeStackTrace: true);
      final value = 1.lx;
      value.value = 2;
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final adapter = TaskMonitorAdapter(engine, ownerPath: '1:Uploads');
      final started = Completer<void>();
      final release = Completer<void>();
      final task = engine.schedule((_) async {
        started.complete();
        await release.future;
      });
      await started.future;
      await LevitMonitor.flush();
      final change = sink.events
          .singleWhere(
            (event) =>
                event.toJson()['type'] == 'state_change' &&
                event.toJson()['reactiveId'] == value.id.toString(),
          )
          .toJson();
      expect(
        change['stackTrace'],
        contains('awaited_monitor_contract_test.dart'),
      );
      expect(
        (LevitMonitor.snapshot!['taskTrees']
            as Map)['1:Uploads']['tree']['runningCount'],
        1,
      );
      release.complete();
      await task;
      await adapter.dispose();
      await LevitMonitor.flush();
      expect(LevitMonitor.snapshot!['taskTrees'], isEmpty);
      expect(await engine.schedule((_) => 42), 42);
      await engine.dispose();
      await value.close();
    },
  );
  test('worker statistics are opt in and restored on detach', () async {
    Lx.enableWatchMonitoring = false;
    await LevitMonitor.attach(transport: _Sink());
    expect(Lx.enableWatchMonitoring, isFalse);
    await LevitMonitor.attach(transport: _Sink(), enableWorkerStatistics: true);
    expect(Lx.enableWatchMonitoring, isTrue);
    await LevitMonitor.detach();
    expect(Lx.enableWatchMonitoring, isFalse);
  });
  test(
    'scope progress identifies pending initialization and unfinished cleanup',
    () async {
      final sink = _Sink();
      await LevitMonitor.attach(transport: sink);
      final scope = LevitScope.root('project');
      final init = Completer<void>();
      final finishing = Completer<void>();
      scope.trackInitialization(init.future);
      scope.put(() => _Resource(finishing.future));
      final closing = scope.dispose();
      await LevitMonitor.flush();
      final progress =
          (LevitMonitor.snapshot!['scopes'] as List).single['progress'] as Map;
      expect(progress['isClosing'], isTrue);
      expect(progress['pendingInitializations'], 1);
      init.complete();
      await Future<void>.delayed(Duration.zero);
      await LevitMonitor.flush();
      expect((LevitMonitor.snapshot!['scopes'] as List), isNotEmpty);
      finishing.complete();
      await closing;
      await LevitMonitor.flush();
      expect(LevitMonitor.snapshot!['scopes'], isEmpty);
    },
  );
}

class _Sink extends LevitTransport {
  final events = <MonitorEvent>[];
  bool closed = false;
  @override
  Future<void> send(MonitorEvent event) async {
    events.add(event);
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class _BlockedSink extends _Sink {
  final release = Completer<void>();
  @override
  Future<void> send(MonitorEvent event) async {
    await release.future;
    await super.send(event);
  }
}

class _FailingSink extends _Sink {
  @override
  Future<void> send(MonitorEvent event) async {
    throw StateError('send');
  }

  @override
  Future<void> close() async {
    closed = true;
    throw StateError('close');
  }
}

class _Resource implements LevitDisposable {
  final Future<void> completion;
  _Resource(this.completion);
  @override
  Future<void> dispose() => completion;
}
