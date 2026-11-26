import 'dart:async';
import 'dart:io';

import 'websocket_connection.dart';

/// Opens a WebSocket connection using `dart:io`.
LevitWebSocketConnection connectWebSocket(Uri uri) =>
    _IoWebSocketConnection(uri);

final class _IoWebSocketConnection implements LevitWebSocketConnection {
  final StreamController<Object?> _incoming = StreamController<Object?>();
  final Completer<void> _ready = Completer<void>();
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;

  _IoWebSocketConnection(Uri uri) {
    unawaited(_connect(uri));
  }

  Future<void> _connect(Uri uri) async {
    try {
      final socket = await WebSocket.connect(uri.toString());
      if (_closed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _subscription = socket.listen(
        _incoming.add,
        onError: _incoming.addError,
        onDone: () {
          if (!_incoming.isClosed) unawaited(_incoming.close());
        },
        cancelOnError: false,
      );
      _ready.complete();
    } catch (error, stackTrace) {
      if (!_ready.isCompleted) {
        _ready.completeError(error, stackTrace);
      }
      if (!_incoming.isClosed) {
        unawaited(_incoming.close());
      }
    }
  }

  @override
  Stream<Object?> get stream => _incoming.stream;

  @override
  Future<void> get ready => _ready.future;

  @override
  void send(String data) {
    final socket = _socket;
    if (_closed || socket == null) {
      throw StateError('WebSocket connection is not open.');
    }
    socket.add(data);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    await _socket?.close(code, reason);
    if (!_incoming.isClosed) {
      unawaited(_incoming.close());
    }
  }
}
