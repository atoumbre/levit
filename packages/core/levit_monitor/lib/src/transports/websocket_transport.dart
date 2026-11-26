part of '../monitor_library.dart';

/// Bounded WebSocket delivery to the local inspector or telemetry relay.
///
/// When [requireAcknowledgement] is `true`, the relay acknowledges each event
/// with `{"ack": <seq>}`. Disconnection or queue overflow drops events with
/// accounting in [droppedEvents]; emitting on [onConnect] triggers a reconnect
/// snapshot to restore state without claiming complete history.
///
/// Use [LevitWebSocketTransport.connect] for automatic reconnection with
/// exponential backoff (`1s` up to `32s`), or the default constructor to wrap
/// an externally managed `WebSocketChannel`.
///
/// ```dart
/// final transport = LevitWebSocketTransport.connect(
///   'ws://127.0.0.1:9200/ws',
///   appId: 'my-app',
/// );
/// await LevitMonitor.attach(transport: transport);
/// ```
///
/// {@category Middleware & Monitoring}
class LevitWebSocketTransport extends LevitTransport {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final String? _url;
  final String? _appId;
  final String? _token;
  final WebSocketChannel Function(Uri)? _channelBuilder;
  final void Function(LevitWebSocketTransport)? _onReady;
  final void Function(Object)? _onError;

  /// Maximum number of buffered + in-flight events before evicting the oldest
  /// queued event (must be >= 1; defaults to `256`).
  final int capacity;

  /// Maximum time to wait for channel readiness or an `{"ack": <seq>}` reply
  /// before disconnecting and dropping pending events (defaults to 5 seconds).
  final Duration acknowledgementTimeout;

  /// Whether each outbound event waits for an explicit `{"ack": <seq>}` reply
  /// before advancing the queue (defaults to `true`).
  final bool requireAcknowledgement;

  /// Whether cleartext `ws://` connections to non-loopback hosts are allowed.
  ///
  /// Defaults to `false`: `ws://` is restricted to loopback hosts
  /// (`localhost`, `127.0.0.1`, `::1`) unless explicitly opted in.
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

  /// Wraps an already-constructed `WebSocketChannel` without automatic
  /// reconnection.
  ///
  /// Throws a [RangeError] if [capacity] < 1 or an [ArgumentError] if
  /// [acknowledgementTimeout] is not positive.
  LevitWebSocketTransport(
    WebSocketChannel channel, {
    this.capacity = 256,
    this.acknowledgementTimeout = const Duration(seconds: 5),
    this.requireAcknowledgement = true,
  }) : _url = null,
       _appId = null,
       _token = null,
       _channelBuilder = null,
       _onReady = null,
       _onError = null,
       allowInsecureRemote = false {
    _validate();
    _adopt(channel);
  }
  LevitWebSocketTransport._(
    this._url,
    this._appId,
    this._token,
    this._channelBuilder,
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

  /// Connects to [serverUrl] (`ws://` for loopback or `wss://` for remote
  /// hosts) with automatic exponential-backoff reconnection (`1s` to `32s`).
  ///
  /// * [serverUrl]: Target WebSocket endpoint. Non-loopback `ws://` URLs throw
  ///   an [ArgumentError] unless [allowInsecureRemote] is `true`.
  /// * [appId]: Optional application identifier appended as a query parameter.
  /// * [token]: Optional authentication token sent when connecting.
  /// * [channelBuilder]: Optional factory for testing or custom channels.
  /// * [onReady]: Optional callback invoked each time the socket becomes ready.
  /// * [onError]: Optional callback invoked on socket errors.
  /// * [capacity] / [acknowledgementTimeout] / [requireAcknowledgement] /
  ///   [allowInsecureRemote]: Buffering, timeout, ack, and TLS controls.
  static LevitWebSocketTransport connect(
    String serverUrl, {
    String? appId,
    String? token,
    WebSocketChannel Function(Uri)? channelBuilder,
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
    channelBuilder,
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
      _adopt(_channelBuilder?.call(uri) ?? WebSocketChannel.connect(uri));
    } catch (error) {
      _onError?.call(error);
      _scheduleReconnect();
    }
  }

  void _adopt(WebSocketChannel channel) {
    _channel = channel;
    _subscription = channel.stream.listen(
      (message) {
        if (!identical(_channel, channel)) return;
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
      onDone: () => _disconnect(channel),
      onError: (Object error) {
        _onError?.call(error);
        _disconnect(channel);
      },
      // _disconnect owns and awaits cancellation. Automatic stream cancellation
      // would send a failed cancellation Future to the zone before we can drain it.
      cancelOnError: false,
    );
    channel.ready
        .timeout(acknowledgementTimeout)
        .then(
          (_) {
            if (!identical(_channel, channel) || _closing) return;
            _ready = true;
            _retryAttempts = 0;
            _onConnectController.add(null);
            _onReady?.call(this);
            _pump();
          },
          onError: (Object error, StackTrace stack) {
            _onError?.call(error);
            _disconnect(channel);
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

  void _disconnect(WebSocketChannel channel) {
    if (!identical(_channel, channel)) return;
    _channel = null;
    _ready = false;
    _ackTimer?.cancel();
    final subscription = _subscription;
    _subscription = null;
    late Future<void> cleanup;
    cleanup = () async {
      for (final release in [
        () async => subscription?.cancel(),
        () async => channel.sink.close(),
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
    if (_channel == null) {
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
      _channel!.sink.add(delivery.event.encode());
      if (!requireAcknowledgement) {
        scheduleMicrotask(_acknowledge);
      } else {
        _ackTimer = Timer(acknowledgementTimeout, () {
          final channel = _channel;
          if (channel != null) _disconnect(channel);
        });
      }
    } catch (error) {
      _onError?.call(error);
      final channel = _channel;
      if (channel != null) _disconnect(channel);
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
    // Pending connection setup has no delivered work. Closing its channel is
    // awaited below; such queued events are counted as dropped.
    if (!_ready) _dropPending();
    return _closeFuture = () async {
      final errors = <AsyncError>[];
      try {
        await flush();
      } catch (error, stack) {
        errors.add(AsyncError(error, stack));
      }
      final channel = _channel;
      _channel = null;
      try {
        await _subscription?.cancel();
      } catch (error, stack) {
        errors.add(AsyncError(error, stack));
      }
      try {
        await channel?.sink.close();
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
