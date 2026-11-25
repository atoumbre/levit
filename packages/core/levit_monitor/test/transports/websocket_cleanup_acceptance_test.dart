import 'dart:async';
import 'dart:convert';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/monitor_failure_acceptance_test.dart' show envelope;
import 'package:levit_monitor/spi.dart';

class SocketSink implements WebSocketSink {
  Object? error;
  final sent = <Object?>[];
  bool closed = false;
  @override
  void add(dynamic data) => sent.add(data);
  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Channel implements WebSocketChannel {
  Channel({this.cancelError, this.cancelGate});
  final Object? cancelError;
  final Completer<void>? cancelGate;
  final connected = Completer<void>();
  late final input = StreamController<dynamic>(
    onCancel: () async {
      await cancelGate?.future;
      if (cancelError != null) throw cancelError!;
    },
  );
  @override
  final SocketSink sink = SocketSink();
  @override
  Stream<dynamic> get stream => input.stream;
  @override
  Future<void> get ready => connected.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('bounds validate before connecting', () {
    expect(
      () => LevitWebSocketTransport(Channel(), capacity: 0),
      throwsRangeError,
    );
    expect(
      () => LevitWebSocketTransport(
        Channel(),
        acknowledgementTimeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });

  test(
    'queue overflow drops oldest pending events and flush awaits acknowledgement',
    () async {
      final channel = Channel();
      final transport = LevitWebSocketTransport(channel, capacity: 2);
      final first = transport.send(LevitFrozenMonitorEvent(envelope('first')));
      final second = transport.send(
        LevitFrozenMonitorEvent(envelope('second')),
      );
      final third = transport.send(LevitFrozenMonitorEvent(envelope('third')));
      await first;
      expect(transport.droppedEvents, 1);
      channel.connected.complete();
      await Future<void>.delayed(Duration.zero);
      expect(jsonDecode(channel.sink.sent.single as String)['type'], 'second');
      var flushed = false;
      final flushing = transport.flush().then((_) => flushed = true);
      channel.input.add('{unrelated');
      channel.input.add(jsonEncode({'ack': -1}));
      await Future<void>.delayed(Duration.zero);
      expect(flushed, isFalse);
      channel.input.add(jsonEncode({'ack': 1}));
      await second;
      channel.input.add(jsonEncode({'ack': 1}));
      await third;
      await flushing;
      await transport.close();
      await transport.send(LevitFrozenMonitorEvent(envelope('closed')));
      expect(channel.sink.sent.length, 2);
      await channel.input.close();
    },
  );

  test(
    'full in-flight slot drops new events and timeout disconnects with accounting',
    () async {
      final channel = Channel()..connected.complete();
      final transport = LevitWebSocketTransport(
        channel,
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
      await channel.input.close();
    },
  );

  test('acknowledgement-free transport drains without relay support', () async {
    final channel = Channel()..connected.complete();
    final transport = LevitWebSocketTransport(
      channel,
      requireAcknowledgement: false,
    );
    await transport.send(LevitFrozenMonitorEvent(envelope('event')));
    await transport.close();
    expect(channel.sink.sent, hasLength(1));
    await channel.input.close();
  });

  for (final disconnect in [false, true]) {
    test(
      'cleanup drains both subscription and socket failures, disconnect=$disconnect',
      () async {
        final gate = Completer<void>();
        final channel = Channel(
          cancelError: StateError('subscription'),
          cancelGate: gate,
        )..connected.complete();
        channel.sink.error = StateError('socket');
        final transport = LevitWebSocketTransport(channel);
        await Future<void>.delayed(Duration.zero);
        if (disconnect) channel.input.addError(StateError('lost connection'));
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
        expect(channel.sink.closed, isTrue);
        await channel.input.close();
      },
    );
  }

  test(
    'close before ready drops pending events and awaits failed channel release',
    () async {
      final channel = Channel(cancelError: StateError('subscription'));
      channel.sink.error = StateError('socket');
      final transport = LevitWebSocketTransport(channel);
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
      channel.connected.complete();
      await channel.input.close();
    },
  );
}
