import 'dart:async';

import 'package:levit_monitor/levit_monitor.dart';
import 'package:logger/logger.dart' hide LogEvent;
import 'package:test/test.dart';

class _CaptureTransport implements LevitTransport {
  final events = <MonitorEvent>[];

  @override
  Stream<void> get onConnect => const Stream<void>.empty();

  @override
  void send(MonitorEvent event) => events.add(event);

  @override
  Future<void> close() async {}
}

class _Unprintable {
  @override
  String toString() => throw StateError('no string');
}

void main() {
  tearDown(() {
    LevitMonitor.detach();
    LevitMonitor.setObfuscator(null);
    LevitMonitor.setFilter(null);
  });

  test('custom event preserves safe structured attributes', () {
    final timestamp = DateTime.utc(2026, 1, 2);
    final event = CustomMonitorEvent(
      sessionId: 'session',
      namespace: 'levit.task',
      name: 'finished',
      level: Level.debug,
      attributes: {
        'category': 'sync',
        'attempt': 2,
        'at': timestamp,
        'duration': const Duration(microseconds: 42),
        'uri': Uri.parse('https://example.test'),
        'nested': {
          7: [_Unprintable(), true],
        },
      },
    );

    final json = event.toJson();
    expect(json['type'], 'custom');
    expect(json['namespace'], 'levit.task');
    expect(json['name'], 'finished');
    expect(json['level'], 'debug');
    expect(json['isSensitive'], isFalse);
    expect(json['attributes']['at'], timestamp.toIso8601String());
    expect(json['attributes']['duration'], 42);
    expect(json['attributes']['uri'], 'https://example.test');
    expect(json['attributes']['nested']['7'][0], '<unprintable>');
  });

  test('sensitive custom event redacts attributes and errors', () {
    LevitMonitor.setObfuscator((_) => '<redacted>');
    final event = CustomMonitorEvent(
      sessionId: 'session',
      namespace: 'levit.task',
      name: 'failed',
      sensitive: true,
      attributes: const {'shop': 'secret'},
      error: StateError('secret error'),
      stackTrace: StackTrace.fromString('secret stack'),
    );

    final json = event.toJson();
    expect(json['attributes'], '<redacted>');
    expect(json['error'], '<redacted>');
    expect(json['stackTrace'], '<redacted>');
    expect(json.toString(), isNot(contains('secret')));
  });

  test('LevitMonitor emits custom events through the existing pipeline',
      () async {
    final transport = _CaptureTransport();
    LevitMonitor.attach(transport: transport);
    LevitMonitor.setFilter(
      (event) => event is CustomMonitorEvent && event.name == 'started',
    );

    LevitMonitor.emitCustomEvent(
      namespace: 'levit.task',
      name: 'ignored',
    );
    LevitMonitor.emitCustomEvent(
      namespace: 'levit.task',
      name: 'started',
      attributes: const {'category': 'sync'},
    );
    await Future<void>.delayed(Duration.zero);

    expect(transport.events, hasLength(1));
    final event = transport.events.single as CustomMonitorEvent;
    expect(event.attributes, {'category': 'sync'});
  });

  test('emitting while detached is a no-op', () {
    LevitMonitor.detach();
    expect(
      () => LevitMonitor.emitCustomEvent(
        namespace: 'levit.task',
        name: 'started',
      ),
      returnsNormally,
    );
  });

  test('custom event validates stable names', () {
    expect(
      () => CustomMonitorEvent(
        sessionId: 's',
        namespace: ' ',
        name: 'event',
      ),
      throwsArgumentError,
    );
    expect(
      () => CustomMonitorEvent(
        sessionId: 's',
        namespace: 'app',
        name: '',
      ),
      throwsArgumentError,
    );
  });
}
