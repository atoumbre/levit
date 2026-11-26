part of '../monitor_library.dart';

/// Bounded WebSocket delivery to a local MCP relay or inspector. The relay
/// acknowledges events by sequence number. Disconnection drops queued events
/// with accounting; a reconnect snapshot restores state without claiming
/// complete history.
class LevitWebSocketTransport extends LevitTransport {
  LevitWebSocketConnection? _connection;
  StreamSubscription<Object?>? _subscription;
  final String? _url;
  final String? _appId;
  final String? _token;
  final LevitWebSocketConnection Function(Uri)? _connectionBuilder;
  final void Function(LevitWebSocketTransport)? _onReady;
  final void Function(Object)? _onError;

  /// Maximum number of queued and in-flight events retained before dropping.
  final int capacity;

  /// Deadline for connection readiness and per-event relay acknowledgements.
  final Duration acknowledgementTimeout;

  /// Whether each event waits for a relay `{"ack": seq}` before pumping next.
  final bool requireAcknowledgement;

  /// Whether cleartext `ws://` connections to non-loopback hosts are permitted.
  final bool allowInsecureRemote;
  final _onConnectController = StreamController<void>.broadcast();
  final ListQueue<_SocketDelivery> _queue = ListQueue();
  _SocketDelivery? _inFlight;
  Timer? _ackTimer;
  Timer? _reconnectTimer;
  Future<void>? _closeFuture;
  final Set<Future<void>> _cleanup = {};
  final List<AsyncError> _cleanupErrors = [];
  bool _ready = false;
  bool _closing = false;
  int _retryAttempts = 0;
  int _dropped = 0;

  /// Creates a [LevitWebSocketTransport] wrapping an existing
  /// [LevitWebSocketConnection].
  LevitWebSocketTransport(
    LevitWebSocketConnection connection, {
    this.capacity = 256,
    this.acknowledgementTimeout = const Duration(seconds: 5),
    this.requireAcknowledgement = true,
  }) : _url = null,
       _appId = null,
       _token = null,
       _connectionBuilder = null,
       _onReady = null,
       _onError = null,
       allowInsecureRemote = false {
    _validate();
    _adopt(connection);
  }

  LevitWebSocketTransport._(
    this._url,
    this._appId,
    this._token,
    this._connectionBuilder,
    this._onReady,
    this._onError,
    this.capacity,
    this.acknowledgementTimeout,
    this.requireAcknowledgement,
    this.allowInsecureRemote,
  ) {
    _validate();
    _connect();
  }

  void _validate() {
    if (capacity < 1) throw RangeError.value(capacity, 'capacity');
    if (acknowledgementTimeout <= Duration.zero) {
      throw ArgumentError.value(
        acknowledgementTimeout,
        'acknowledgementTimeout',
      );
    }
    if (_url case final rawUrl?) {
      final uri = Uri.parse(rawUrl);
      if (uri.scheme != 'ws' && uri.scheme != 'wss') {
        throw ArgumentError.value(
          rawUrl,
          'serverUrl',
          'WebSocket URL scheme must be ws or wss.',
        );
      }
      if (uri.scheme == 'ws' &&
          !allowInsecureRemote &&
          !_isLoopbackHost(uri.host)) {
        throw ArgumentError.value(
          rawUrl,
          'serverUrl',
          'Cleartext ws:// to non-loopback hosts requires allowInsecureRemote: true.',
        );
      }
    }
  }

  static bool _isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1' ||
        normalized == '[::1]';
  }

  /// Connects to [serverUrl] using the platform WebSocket implementation (or
  /// [connectionBuilder] when supplied) with automatic exponential backoff.
  static LevitWebSocketTransport connect(
    String serverUrl, {
    String? appId,
    String? token,
    LevitWebSocketConnection Function(Uri)? connectionBuilder,
    void Function(LevitWebSocketTransport)? onReady,
    void Function(Object)? onError,
    int capacity = 256,
    Duration acknowledgementTimeout = const Duration(seconds: 5),
    bool requireAcknowledgement = true,
    bool allowInsecureRemote = false,
  }) => LevitWebSocketTransport._(
    serverUrl,
    appId,
    token,
    connectionBuilder,
    onReady,
    onError,
    capacity,
    acknowledgementTimeout,
    requireAcknowledgement,
    allowInsecureRemote,
  );

  @override
  int get droppedEvents => _dropped;

  @override
  Stream<void> get onConnect => _onConnectController.stream;

  void _connect() {
    if (_closing) return;
    try {
      var uri = Uri.parse(_url!);
      uri = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          if (_appId != null) 'appId': _appId,
          if (_token != null && _token.isNotEmpty) 'token': _token,
        },
      );
      _adopt(_connectionBuilder?.call(uri) ?? connectWebSocket(uri));
    } catch (error) {
      _onError?.call(error);
      _scheduleReconnect();
    }
  }

  void _adopt(LevitWebSocketConnection connection) {
    _connection = connection;
    _subscription = connection.stream.listen(
      (message) {
        if (!identical(_connection, connection)) return;
        if (message is String) {
          try {
            final data = jsonDecode(message);
            if (data is Map && data['ack'] == _inFlight?.event.seq) {
              _acknowledge();
            }
          } catch (_) {
            /* Ignore unrelated consumer messages. */
          }
        }
      },
      onDone: () => _disconnect(connection),
      onError: (Object error) {
        _onError?.call(error);
        _disconnect(connection);
      },
      // _disconnect owns and awaits cancellation. Automatic stream cancellation
      // would send a failed cancellation Future to the zone before we can drain it.
      cancelOnError: false,
    );
    connection.ready
        .timeout(acknowledgementTimeout)
        .then(
          (_) {
            if (!identical(_connection, connection) || _closing) return;
            _ready = true;
            _retryAttempts = 0;
            _onConnectController.add(null);
            _onReady?.call(this);
            _pump();
          },
          onError: (Object error, StackTrace stack) {
            _onError?.call(error);
            _disconnect(connection);
          },
        );
  }

  void _acknowledge() {
    _ackTimer?.cancel();
    _ackTimer = null;
    _inFlight?.complete.complete();
    _inFlight = null;
    _pump();
  }

  void _disconnect(LevitWebSocketConnection connection) {
    if (!identical(_connection, connection)) return;
    _connection = null;
    _ready = false;
    _ackTimer?.cancel();
    final subscription = _subscription;
    _subscription = null;
    late Future<void> cleanup;
    cleanup = () async {
      for (final release in [
        () async => subscription?.cancel(),
        () async => connection.close(),
      ]) {
        try {
          await release();
        } catch (error, stack) {
          if (_cleanupErrors.length < 32) {
            _cleanupErrors.add(AsyncError(error, stack));
          }
        }
      }
    }().whenComplete(() => _cleanup.remove(cleanup));
    _cleanup.add(cleanup);
    _dropPending();
    _scheduleReconnect();
  }

  void _dropPending() {
    final inFlight = _inFlight;
    _inFlight = null;
    if (inFlight != null) {
      _dropped++;
      inFlight.complete.complete();
    }
    while (_queue.isNotEmpty) {
      _dropped++;
      _queue.removeFirst().complete.complete();
    }
  }

  void _scheduleReconnect() {
    if (_closing || _url == null || (_reconnectTimer?.isActive ?? false)) {
      return;
    }
    final seconds = (1 << _retryAttempts.clamp(0, 5)).clamp(1, 32);
    _retryAttempts++;
    _reconnectTimer = Timer(Duration(seconds: seconds), _connect);
  }

  @override
  Future<void> send(LevitMonitorEvent event) {
    if (_closing) return Future.value();
    final frozen = event.freeze();
    if (_connection == null) {
      _dropped++;
      return Future.value();
    }
    if (_queue.length + (_inFlight == null ? 0 : 1) >= capacity) {
      _dropped++;
      if (_queue.isEmpty) return Future.value();
      _queue.removeFirst().complete.complete();
    }
    final delivery = _SocketDelivery(frozen.envelope);
    _queue.add(delivery);
    _pump();
    return delivery.complete.future;
  }

  void _pump() {
    if (!_ready || _inFlight != null || _queue.isEmpty) return;
    final delivery = _queue.removeFirst();
    _inFlight = delivery;
    try {
      _connection!.send(delivery.event.encode());
      if (!requireAcknowledgement) {
        scheduleMicrotask(_acknowledge);
      } else {
        _ackTimer = Timer(acknowledgementTimeout, () {
          final connection = _connection;
          if (connection != null) _disconnect(connection);
        });
      }
    } catch (error) {
      _onError?.call(error);
      final connection = _connection;
      if (connection != null) _disconnect(connection);
    }
  }

  @override
  Future<void> flush() async {
    while (_queue.isNotEmpty || _inFlight != null) {
      final pending = [
        if (_inFlight != null) _inFlight!.complete.future,
        ..._queue.map((entry) => entry.complete.future),
      ];
      await Future.wait(pending);
    }
    while (_cleanup.isNotEmpty) {
      await Future.wait(_cleanup.toList());
    }
    if (_cleanupErrors.isNotEmpty) {
      throw LevitMonitorException(_cleanupErrors);
    }
  }

  @override
  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    _closing = true;
    _reconnectTimer?.cancel();
    // Pending connection setup has no delivered work. Closing its connection is
    // awaited below; such queued events are counted as dropped.
    if (!_ready) _dropPending();
    return _closeFuture = () async {
      final errors = <AsyncError>[];
      try {
        await flush();
      } catch (error, stack) {
        errors.add(AsyncError(error, stack));
      }
      final connection = _connection;
      _connection = null;
      try {
        await _subscription?.cancel();
      } catch (error, stack) {
        errors.add(AsyncError(error, stack));
      }
      try {
        await connection?.close();
      } catch (error, stack) {
        errors.add(AsyncError(error, stack));
      }
      await _onConnectController.close();
      if (errors.isNotEmpty) throw LevitMonitorException(errors);
    }();
  }
}

final class _SocketDelivery {
  final LevitEventEnvelope event;
  final complete = Completer<void>();
  _SocketDelivery(this.event);
}
