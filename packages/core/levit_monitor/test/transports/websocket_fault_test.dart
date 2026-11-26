import 'dart:async';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

class _MockConnection implements LevitWebSocketConnection {
  bool closed = false;
  final List<String> sent = [];
  final StreamController<Object?> _controller = StreamController<Object?>();

  @override
  Stream<Object?> get stream => _controller.stream;

  @override
  Future<void> get ready => Future.value();

  @override
  void send(String data) {
    if (closed) throw 'Sink closed';
    sent.add(data);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
  }
}

class _MockConnectionWithReadyError extends _MockConnection {
  @override
  Future<void> get ready => Future.error('Intentional ready error');
}

void main() {
  group('LevitWebSocketTransport Fault Handling', () {
    test(
      'Handles invalid URL connection failure by scheduling reconnect',
      () async {
        int builderCalls = 0;

        final transport = LevitWebSocketTransport.connect(
          'ws://invalid-url',
          allowInsecureRemote: true,
          connectionBuilder: (uri) {
            builderCalls++;
            throw 'Connection failed';
          },
        );

        await Future.delayed(Duration(milliseconds: 1100));
        expect(builderCalls, greaterThanOrEqualTo(2));
        await transport.close();
      },
    );

    test('Triggers onReady callback when ready future completes', () async {
      int onReadyCalls = 0;
      final transport = LevitWebSocketTransport.connect(
        'ws://localhost',
        connectionBuilder: (uri) => _MockConnection(),
        onReady: (t) {
          onReadyCalls++;
        },
      );

      await Future.delayed(Duration(milliseconds: 100));
      expect(onReadyCalls, 1);
      await transport.close();
    });

    test('Handles ready future error and triggers onError callback', () async {
      int onErrorCalls = 0;
      final transport = LevitWebSocketTransport.connect(
        'ws://localhost',
        connectionBuilder: (uri) => _MockConnectionWithReadyError(),
        onError: (e) {
          onErrorCalls++;
          expect(e, equals('Intentional ready error'));
        },
      );

      await Future.delayed(Duration(milliseconds: 100));
      expect(onErrorCalls, 1);
      await transport.close();
    });

    test('Handling disconnect during send triggers reconnect', () async {
      final mockConnection = _MockConnection();
      int connectCount = 0;

      final transport = LevitWebSocketTransport.connect(
        'ws://localhost',
        connectionBuilder: (uri) {
          connectCount++;
          if (connectCount == 1) return mockConnection;
          return _MockConnection();
        },
      );

      await Future.delayed(Duration(milliseconds: 10));
      mockConnection.closed = true;

      final rx = 0.lx.named('test');
      transport.send(LevitReactiveInitEvent(sessionId: 's', reactive: rx));

      await Future.delayed(Duration(milliseconds: 1100));
      expect(connectCount, greaterThanOrEqualTo(2));
      await transport.close();
    });
  });
}
