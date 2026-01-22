import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/event.dart';
import '../core/transport.dart';

/// A transport that sends [MonitorEvent]s via WebSocket.
class WebSocketTransport implements LevitTransport {
  /// The WebSocket channel for communication.
  WebSocketChannel? _channel;

  /// Whether the user has explicitly closed the transport.
  bool _isDisposed = false;

  // Managed connection details
  final String? _url;
  final String? _appId;
  final WebSocketChannel Function(Uri uri)? _channelBuilder;

  // Reconnection state
  Timer? _reconnectTimer;
  int _retryAttempts = 0;

  /// Creates a [WebSocketTransport] from an existing [WebSocketChannel].
  WebSocketTransport(WebSocketChannel channel)
      : _url = null,
        _appId = null,
        _channelBuilder = null {
    _channel = channel;
    _listenToChannel(channel);
  }

  WebSocketTransport._(this._url, this._appId, this._channelBuilder) {
    _connect();
  }

  /// Connects to a server at the given URL.
  static WebSocketTransport connect(
    String serverUrl, {
    String? appId,
    WebSocketChannel Function(Uri uri)? channelBuilder,
  }) {
    return WebSocketTransport._(serverUrl, appId, channelBuilder);
  }

  void _connect() {
    if (_isDisposed) return;

    try {
      var uri = Uri.parse(_url!);
      final queryParams = Map<String, dynamic>.from(uri.queryParameters);
      if (_appId != null) {
        queryParams['appId'] = _appId!;
      }
      uri = uri.replace(queryParameters: queryParams);

      _channel = _channelBuilder?.call(uri) ?? WebSocketChannel.connect(uri);
      _listenToChannel(_channel!);
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _listenToChannel(WebSocketChannel channel) {
    channel.stream.listen(
      (_) {
        if (_retryAttempts > 0) _retryAttempts = 0;
      },
      onDone: _handleDisconnect,
      onError: (_) => _handleDisconnect(),
      cancelOnError: true,
    );
  }

  void _handleDisconnect() {
    _channel = null;
    if (!_isDisposed && _url != null) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed || (_reconnectTimer?.isActive ?? false)) return;

    final delaySeconds = (1 << _retryAttempts).clamp(1, 32);
    final delay = Duration(seconds: delaySeconds);

    _retryAttempts++;
    _reconnectTimer = Timer(delay, _connect);
  }

  void _send(Map<String, dynamic> data) {
    if (_isDisposed) return;
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(data));
    } catch (_) {
      _handleDisconnect();
    }
  }

  @override
  void send(MonitorEvent event) {
    final category = switch (event) {
      ReactiveEvent _ || ReactiveBatchEvent _ => 'state',
      DependencyEvent _ => 'di',
    };

    _send({
      'category': category,
      ...event.toJson(),
    });
  }

  @override
  void close() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
