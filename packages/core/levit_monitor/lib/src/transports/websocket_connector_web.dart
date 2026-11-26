import 'dart:async';
import 'dart:js_interop';

import 'websocket_connection.dart';

/// Opens a browser WebSocket connection using `dart:js_interop`.
LevitWebSocketConnection connectWebSocket(Uri uri) =>
    _WebWebSocketConnection(uri);

@JS('WebSocket')
extension type _JsWebSocket._(JSObject _) implements JSObject {
  external factory _JsWebSocket(String url);
  external void send(JSAny data);
  external void close([int? code, String? reason]);
  external set onopen(JSFunction? handler);
  external set onmessage(JSFunction? handler);
  external set onerror(JSFunction? handler);
  external set onclose(JSFunction? handler);
}

extension type _JsMessageEvent._(JSObject _) implements JSObject {
  external JSAny? get data;
}

final class _WebWebSocketConnection implements LevitWebSocketConnection {
  final StreamController<Object?> _incoming = StreamController<Object?>();
  final Completer<void> _ready = Completer<void>();
  late final _JsWebSocket _socket;
  bool _open = false;
  bool _closed = false;

  _WebWebSocketConnection(Uri uri) {
    _socket = _JsWebSocket(uri.toString());
    _socket.onopen = ((JSAny? _) {
      if (_closed) return;
      _open = true;
      if (!_ready.isCompleted) _ready.complete();
    }).toJS;
    _socket.onmessage = ((_JsMessageEvent event) {
      if (_closed || _incoming.isClosed) return;
      final data = event.data;
      if (data != null && data.isA<JSString>()) {
        _incoming.add((data as JSString).toDart);
      }
    }).toJS;
    _socket.onerror = ((JSAny? _) {
      final error = StateError('WebSocket connection error.');
      if (!_ready.isCompleted) {
        _ready.completeError(error);
      } else if (!_incoming.isClosed) {
        _incoming.addError(error);
      }
    }).toJS;
    _socket.onclose = ((JSAny? _) {
      _open = false;
      if (!_ready.isCompleted) {
        _ready.completeError(StateError('WebSocket closed before ready.'));
      }
      if (!_incoming.isClosed) {
        unawaited(_incoming.close());
      }
    }).toJS;
  }

  @override
  Stream<Object?> get stream => _incoming.stream;

  @override
  Future<void> get ready => _ready.future;

  @override
  void send(String data) {
    if (_closed || !_open) {
      throw StateError('WebSocket connection is not open.');
    }
    _socket.send(data.toJS);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_closed) return;
    _closed = true;
    _open = false;
    _socket.onopen = null;
    _socket.onmessage = null;
    _socket.onerror = null;
    _socket.onclose = null;
    if (code != null && reason != null) {
      _socket.close(code, reason);
    } else if (code != null) {
      _socket.close(code);
    } else {
      _socket.close();
    }
    if (!_incoming.isClosed) {
      unawaited(_incoming.close());
    }
  }
}
