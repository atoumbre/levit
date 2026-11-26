import 'dart:async';
import 'dart:convert';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

import '../core/monitor_failure_acceptance_test.dart' show envelope;
import 'package:levit_monitor/spi.dart';

class FakeConnection implements LevitWebSocketConnection {
  FakeConnection({this.cancelError, this.cancelGate});
  final Object? cancelError;
  final Completer<void>? cancelGate;
  final connected = Completer<void>();
  Object? closeError;
  final sent = <String>[];
  bool closed = false;
  late final input = StreamController<Object?>(
    onCancel: () async {
      await cancelGate?.future;
      if (cancelError != null) throw cancelError!;
    },
  );
  @override
  Stream<Object?> get stream => input.stream;
  @override
  Future<void> get ready => connected.future;
  @override
  void send(String data) => sent.add(data);
  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    if (closeError != null) throw closeError!;
  }
}

void main() {
  test('bounds validate before connecting', () {
    expect(
      () => LevitWebSocketTransport(FakeConnection(), capacity: 0),
      throwsRangeError,
    );
    expect(
      () => LevitWebSocketTransport(
        FakeConnection(),
        acknowledgementTimeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });

  test(
    'queue overflow drops oldest pending events and flush awaits acknowledgement',
    () async {
      final connection = FakeConnection();
      final transport = LevitWebSocketTransport(connection, capacity: 2);
      final first = transport.send(LevitFrozenMonitorEvent(envelope('first')));
      final second = transport.send(
        LevitFrozenMonitorEvent(envelope('second')),
      );
      final third = transport.send(LevitFrozenMonitorEvent(envelope('third')));
      await first;
      expect(transport.droppedEvents, 1);
      connection.connected.complete();
      await Future<void>.delayed(Duration.zero);
      expect(jsonDecode(connection.sent.single)['type'], 'second');
      var flushed = false;
      final flushing = transport.flush().then((_) => flushed = true);
      connection.input.add('{unrelated');
      connection.input.add(jsonEncode({'ack': -1}));
      await Future<void>.delayed(Duration.zero);
      expect(flushed, isFalse);
      connection.input.add(jsonEncode({'ack': 1}));
      await second;
      connection.input.add(jsonEncode({'ack': 1}));
      await third;
      await flushing;
      await transport.close();
      await transport.send(LevitFrozenMonitorEvent(envelope('closed')));
      expect(connection.sent.length, 2);
      await connection.input.close();
    },
  );

  test(
    'full in-flight slot drops new events and timeout disconnects with accounting',
    () async {
      final connection = FakeConnection()..connected.complete();
      final transport = LevitWebSocketTransport(
        connection,
        capacity: 1,
        acknowledgementTimeout: const Duration(milliseconds: 20),
      );
      await Future<void>.delayed(Duration.zero);
      final first = transport.send(LevitFrozenMonitorEvent(envelope('first')));
      await transport.send(LevitFrozenMonitorEvent(envelope('dropped')));
      expect(transport.droppedEvents, 1);
      await first;
      expect(transport.droppedEvents, 2);
      await transport.send(LevitFrozenMonitorEvent(envelope('offline')));
      expect(transport.droppedEvents, 3);
      await transport.close();
      await connection.input.close();
    },
  );

  test('acknowledgement-free transport drains without relay support', () async {
    final connection = FakeConnection()..connected.complete();
    final transport = LevitWebSocketTransport(
      connection,
      requireAcknowledgement: false,
    );
    await transport.send(LevitFrozenMonitorEvent(envelope('event')));
    await transport.close();
    expect(connection.sent, hasLength(1));
    await connection.input.close();
  });

  for (final disconnect in [false, true]) {
    test(
      'cleanup drains both subscription and socket failures, disconnect=$disconnect',
      () async {
        final gate = Completer<void>();
        final connection = FakeConnection(
          cancelError: StateError('subscription'),
          cancelGate: gate,
        )..connected.complete();
        connection.closeError = StateError('socket');
        final transport = LevitWebSocketTransport(connection);
        await Future<void>.delayed(Duration.zero);
        if (disconnect) {
          connection.input.addError(StateError('lost connection'));
        }
        await Future<void>.delayed(Duration.zero);
        var done = false;
        final closing = transport.close();
        final checked = expectLater(
          closing,
          throwsA(isA<LevitMonitorException>()),
        );
        unawaited(
          closing.then<void>(
            (_) => done = true,
            onError: (Object _) {
              done = true;
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(done, isFalse);
        gate.complete();
        await checked;
        expect(connection.closed, isTrue);
        await connection.input.close();
      },
    );
  }

  test(
    'close before ready drops pending events and awaits failed connection release',
    () async {
      final connection = FakeConnection(
        cancelError: StateError('subscription'),
      );
      connection.closeError = StateError('socket');
      final transport = LevitWebSocketTransport(connection);
      final sending = transport.send(
        LevitFrozenMonitorEvent(envelope('pending')),
      );
      await expectLater(
        transport.close(),
        throwsA(
          isA<LevitMonitorException>().having(
            (e) => e.failures.length,
            'attempted both releases',
            2,
          ),
        ),
      );
      await sending;
      expect(transport.droppedEvents, 1);
      connection.connected.complete();
      await connection.input.close();
    },
  );
}
