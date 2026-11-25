part of '../../levit_monitor.dart';

/// Bounded WebSocket delivery to the local inspector. The relay acknowledges
/// events by sequence number. Disconnection drops queued events with accounting;
/// a reconnect snapshot restores state without claiming complete history.
class WebSocketTransport extends LevitTransport {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final String? _url;
  final String? _appId;
  final WebSocketChannel Function(Uri)? _channelBuilder;
  final void Function(WebSocketTransport)? _onReady;
  final void Function(Object)? _onError;
  final int capacity;
  final Duration acknowledgementTimeout;
  final bool requireAcknowledgement;
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

  WebSocketTransport(
    WebSocketChannel channel, {
    this.capacity = 256,
    this.acknowledgementTimeout = const Duration(seconds: 5),
    this.requireAcknowledgement = true,
  }) : _url = null,
       _appId = null,
       _channelBuilder = null,
       _onReady = null,
       _onError = null {
    _validate();
    _adopt(channel);
  }
  WebSocketTransport._(
    this._url,
    this._appId,
    this._channelBuilder,
    this._onReady,
    this._onError,
    this.capacity,
    this.acknowledgementTimeout,
    this.requireAcknowledgement,
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
  }

  static WebSocketTransport connect(
    String serverUrl, {
    String? appId,
    WebSocketChannel Function(Uri)? channelBuilder,
    void Function(WebSocketTransport)? onReady,
    void Function(Object)? onError,
    int capacity = 256,
    Duration acknowledgementTimeout = const Duration(seconds: 5),
    bool requireAcknowledgement = true,
  }) => WebSocketTransport._(
    serverUrl,
    appId,
    channelBuilder,
    onReady,
    onError,
    capacity,
    acknowledgementTimeout,
    requireAcknowledgement,
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
  Future<void> send(MonitorEvent event) {
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
