part of '../kit_library.dart';

/// A service that can be started, paused, resumed, and stopped.
///
/// It exposes a reactive [status] for state tracking and error reporting.
///
/// {@category Loops, Timers & Selection}
abstract class LevitLoopService {
  /// Reactive status of the service.
  LxReactive<LxStatus<dynamic>> get status;

  /// Starts the service.
  void start();

  /// Pauses the service.
  void pause();

  /// Resumes the service.
  void resume();

  /// Stops the service gracefully.
  Future<void> stop();
}

/// A standalone execution engine for managing repetitive loops and long-running services.
///
/// It supports:
/// *   Sequential loop execution with delays.
/// *   Isolate-based loops for heavy background work.
/// *   Centralized start/pause/resume/stop control for all registered services.
///
/// {@category Loops, Timers & Selection}
class LevitLoopEngine
    implements LevitDisposable, LevitDrainable, LevitExecutionBoundary {
  static final Object _executionZone = Object();
  final Map<String, LevitLoopService> _services = {};
  final Set<String> _permanentServices = {};
  final Set<String> _manuallyPaused = {};
  final Set<String> _bulkPaused = {};
  final Set<Future<void>> _pendingStops = {};
  bool _closing = false;
  Future<void>? _closeFuture;

  /// Registers a [service] under [id].
  ///
  /// Await [stopService] before replacing an existing [id].
  ///
  /// If [permanent] is `true`, the service resists standard calls to
  /// [pauseAllServices] and is only paused when `pauseAllServices(force: true)`
  /// is called. Even permanent services are stopped when the engine is disposed.
  T registerService<T extends LevitLoopService>(
    String id,
    T service, {
    bool permanent = false,
  }) {
    if (_closing) throw StateError('Loop engine is closing.');
    if (_services.containsKey(id)) {
      throw StateError(
        'Await stopService("$id") before registering a replacement.',
      );
    }
    _services[id] = service;
    if (permanent) {
      _permanentServices.add(id);
    } else {
      _permanentServices.remove(id);
    }
    return service;
  }

  /// Starts a sequential loop with the given [id] and [body].
  ///
  /// The [body] is executed repeatedly. The next iteration starts after the
  /// previous one completes and [delay] has passed.
  void startLoop(
    String id,
    Future<void> Function() body, {
    Duration? delay,
    bool permanent = false,
  }) {
    final service = _LoopService(
      () => runZoned(body, zoneValues: {_executionZone: this}),
      delay: delay,
    );
    registerService(id, service, permanent: permanent);
    service.start();
  }

  /// Starts a sequential loop in a separate isolate.
  ///
  /// **Constraint**: The [body] must be a top-level function or a static method.
  /// Closures that capture state cannot be sent across isolate boundaries.
  void startIsolateLoop(
    String id,
    FutureOr<void> Function() body, {
    Duration? delay,
    String? debugName,
    bool permanent = false,
  }) {
    final service = _IsolateLoopService(
      body,
      delay: delay,
      debugName: debugName,
    );
    registerService(id, service, permanent: permanent);
    service.start();
  }

  /// Pauses the service with the given [id].
  void pauseService(String id) {
    _manuallyPaused.add(id);
    _services[id]?.pause();
  }

  /// Resumes the service with the given [id].
  void resumeService(String id) {
    _manuallyPaused.remove(id);
    if (!_bulkPaused.contains(id)) _services[id]?.resume();
  }

  /// Stops the service with the given [id].
  Future<void> stopService(String id) {
    final service = _services[id];
    if (service == null) return Future<void>.value();
    late final Future<void> stopping;
    stopping = Future<void>.sync(service.stop).whenComplete(() {
      if (identical(_services[id], service)) _services.remove(id);
      _permanentServices.remove(id);
      _manuallyPaused.remove(id);
      _bulkPaused.remove(id);
      _pendingStops.remove(stopping);
    });
    _pendingStops.add(stopping);
    return stopping;
  }

  /// Pauses all registered services.
  ///
  /// If [force] is true, pauses all services including permanent ones.
  /// If [force] is false (default), pauses only non-permanent services.
  void pauseAllServices({bool force = false}) {
    for (final entry in _services.entries) {
      if (force || !_permanentServices.contains(entry.key)) {
        _bulkPaused.add(entry.key);
        entry.value.pause();
      }
    }
  }

  /// Resumes registered services that were bulk-paused via [pauseAllServices].
  ///
  /// Services individually paused via [pauseService] remain paused until
  /// [resumeService] is called for their ID.
  ///
  /// If [force] is `true`, also resumes permanent services.
  /// If [force] is `false` (default), resumes only non-permanent services.
  void resumeAllServices({bool force = false}) {
    for (final entry in _services.entries) {
      if (force || !_permanentServices.contains(entry.key)) {
        _bulkPaused.remove(entry.key);
        if (!_manuallyPaused.contains(entry.key)) entry.value.resume();
      }
    }
  }

  /// Stops all registered services.
  ///
  /// This stops EVERYTHING, regardless of permanent status.
  Future<void> stopAllServices() async {
    final results = await Future.wait([
      for (final id in _services.keys.toList())
        stopService(id).then<AsyncError?>(
          (_) => null,
          onError: (Object error, StackTrace stack) => AsyncError(error, stack),
        ),
    ]);
    final errors = results.whereType<AsyncError>().toList();
    if (errors.isNotEmpty)
      throw LevitDisposalException([
        for (final error in errors)
          LevitDisposalFailure(
            resource: this,
            error: error.error,
            stackTrace: error.stackTrace,
          ),
      ]);
  }

  /// The current status, borrowed from the registered service.
  LxReadable<LxStatus<dynamic>>? getServiceStatus(String id) =>
      _services[id]?.status;

  @override
  void requestCancel() {
    if (_closing) return;
    _closing = true;
    for (final service in _services.values) {
      if (service is LevitDrainable) {
        (service as LevitDrainable).requestCancel();
      } else {
        service.pause();
      }
    }
  }

  @override
  Future<void> drain() {
    assertCanDispose();
    requestCancel();
    return _closeFuture ??= stopAllServices();
  }

  @override
  void assertCanDispose() {
    if (identical(Zone.current[_executionZone], this)) {
      throw StateError(
        'A loop cannot dispose its own owner; request cancellation instead.',
      );
    }
  }

  @override
  Future<void> dispose() {
    assertCanDispose();
    requestCancel();
    return drain();
  }
}

/// A shared executor that handles the loop logic, pausing, and throttling of status updates.
class _LoopExecutor {
  final FutureOr<void> Function() _body;
  final Duration? _delay;
  final void Function(LxStatus<dynamic> status) _onStatusChanged;

  bool _isStopped = false;
  bool _isPaused = false;
  Completer<void>? _pauseCompleter;
  Future<void>? _running;
  Timer? _delayTimer;
  Completer<void>? _delayCompleter;
  LxStatus<dynamic> _lastStatus = LxIdle();

  _LoopExecutor(this._body, this._delay, this._onStatusChanged);

  void start() {
    if (_running != null || _isStopped) return;
    _running = _run();
  }

  void pause() {
    if (_isStopped) return;
    _isPaused = true;
    _updateStatus(LxWaiting());
  }

  void resume() {
    if (_isStopped) return;
    _isPaused = false;
    final completer = _pauseCompleter;
    _pauseCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _updateStatus(LxWaiting());
  }

  void requestCancel() {
    _isStopped = true;
    final completer = _pauseCompleter;
    _pauseCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _delayTimer?.cancel();
    if (!(_delayCompleter?.isCompleted ?? true)) _delayCompleter!.complete();
  }

  Future<void> stop() {
    requestCancel();
    return (_running ?? Future<void>.value()).whenComplete(
      () => _updateStatus(LxIdle()),
    );
  }

  void _updateStatus(LxStatus<dynamic> newStatus) {
    if (_lastStatus == newStatus) return;
    _lastStatus = newStatus;
    _onStatusChanged(newStatus);
  }

  Future<void> _run() async {
    _updateStatus(LxWaiting());
    while (!_isStopped) {
      if (_isPaused) {
        _pauseCompleter = Completer<void>();
        await _pauseCompleter!.future;
        if (_isStopped) break;
      }

      try {
        final result = _body();
        if (result is Future) {
          await result;
        }
        _updateStatus(const LxSuccess(null));
      } catch (e, s) {
        _updateStatus(LxError(e, s));
      }

      if (!_isStopped) {
        _delayCompleter = Completer<void>();
        _delayTimer = Timer(_delay ?? Duration.zero, _delayCompleter!.complete);
        await _delayCompleter!.future;
        _delayCompleter = null;
        _delayTimer = null;
      }
    }
  }
}

class _LoopService implements LevitLoopService, LevitDrainable {
  final _status = LxVar<LxStatus<dynamic>>(LxIdle());
  late final _LoopExecutor _executor;

  _LoopService(Future<void> Function() body, {Duration? delay}) {
    _executor = _LoopExecutor(body, delay, (s) => _status.value = s);
  }

  @override
  LxReactive<LxStatus<dynamic>> get status => _status;

  @override
  void start() => _executor.start();

  @override
  void pause() => _executor.pause();

  @override
  void resume() => _executor.resume();

  @override
  void requestCancel() => _executor.requestCancel();

  @override
  Future<void> drain() => _executor.stop();

  @override
  Future<void> stop() async {
    await drain();
    await _status.close();
  }
}

typedef _IsolateSpawner =
    Future<Isolate> Function(
      void Function(_IsolateConfig) entryPoint,
      _IsolateConfig message, {
      String? debugName,
    });

_IsolateSpawner _spawnIsolate =
    (
      void Function(_IsolateConfig) entryPoint,
      _IsolateConfig message, {
      String? debugName,
    }) {
      return Isolate.spawn(
        entryPoint,
        message,
        onError: message.mainSendPort,
        onExit: message.mainSendPort,
        errorsAreFatal: true,
        debugName: debugName,
      );
    };

class _IsolateLoopService implements LevitLoopService, LevitDrainable {
  final FutureOr<void> Function() _body;
  final Duration? _delay;
  final String? _debugName;
  final _status = LxVar<LxStatus<dynamic>>(LxIdle());

  SendPort? _commandPort;
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _receiveSubscription;
  String? _pendingCommand;
  bool _desiredPaused = false;
  bool _stopping = false;
  final Completer<void> _finished = Completer<void>();
  Future<void>? _starting;
  Future<void>? _stopFuture;

  _IsolateLoopService(this._body, {Duration? delay, String? debugName})
    : _delay = delay,
      _debugName = debugName;

  @override
  LxReactive<LxStatus<dynamic>> get status => _status;

  @override
  void start() {
    if (_starting != null || _stopping) return;
    _starting = _start();
  }

  Future<void> _start() async {
    _status.value = LxWaiting();

    await _closeReceivePort();
    if (_stopping) {
      if (!_finished.isCompleted) _finished.complete();
      return;
    }
    try {
      _receivePort = ReceivePort();
      _receiveSubscription = _receivePort!.listen((message) {
        if (message == null) {
          if (!_finished.isCompleted) _finished.complete();
        } else if (message is List) {
          if (!_stopping) {
            final errText = message.isNotEmpty
                ? message[0].toString()
                : 'Isolate error';
            final stackText = message.length > 1 && message[1] != null
                ? message[1].toString()
                : '';
            _status.value = LxError(
              RemoteError(errText, stackText),
              StackTrace.fromString(stackText),
            );
          }
          if (!_finished.isCompleted) _finished.complete();
        } else if (message is SendPort) {
          _commandPort = message;
          final pendingCommand = _stopping ? 'stop' : _pendingCommand;
          if (pendingCommand != null) {
            message.send(pendingCommand);
            _pendingCommand = null;
          }
        } else if (message == 'stopped') {
          if (!_finished.isCompleted) _finished.complete();
        } else if (message is LxStatus<dynamic> && !_stopping) {
          _status.value = message;
        }
      });

      await _spawnIsolate(
        _isolateEntry,
        _IsolateConfig(
          _body,
          _receivePort!.sendPort,
          _delay,
          startPaused: _desiredPaused,
        ),
        debugName: _debugName,
      );
    } catch (e, s) {
      if (!_stopping) _status.value = LxError(e, s);
      if (!_finished.isCompleted) _finished.complete();
      await _closeReceivePort();
    }
  }

  void _dispatchCommand(String command) {
    final port = _commandPort;
    if (port == null) {
      if (_pendingCommand != 'stop') {
        _pendingCommand = command;
      }
      return;
    }
    port.send(command);
  }

  @override
  void pause() {
    if (_stopping) return;
    _desiredPaused = true;
    _dispatchCommand('pause');
    _status.value = LxWaiting();
  }

  @override
  void resume() {
    if (_stopping) return;
    _desiredPaused = false;
    _dispatchCommand('resume');
    _status.value = LxWaiting();
  }

  @override
  Future<void> stop() {
    requestCancel();
    return _stopFuture ??= _stop();
  }

  @override
  void requestCancel() {
    if (_stopping) return;
    _stopping = true;
    _dispatchCommand('stop');
  }

  @override
  Future<void> drain() async {
    requestCancel();
    if (_starting != null) {
      await _starting;
      await _finished.future;
    }
  }

  Future<void> _stop() async {
    await drain();
    _commandPort = null;
    await _closeReceivePort();
    _status.value = LxIdle();
    await _status.close();
  }

  Future<void> _closeReceivePort() async {
    await _receiveSubscription?.cancel();
    _receiveSubscription = null;
    _receivePort?.close();
    _receivePort = null;
  }

  static void _isolateEntry(_IsolateConfig config) async {
    final commandPort = ReceivePort();
    config.mainSendPort.send(commandPort.sendPort);

    final executor = _LoopExecutor(config.body, config.delay, (status) {
      try {
        config.mainSendPort.send(status);
      } catch (_) {
        if (status is LxError<dynamic>) {
          final stackText = status.stackTrace?.toString() ?? '';
          config.mainSendPort.send(
            LxError<dynamic>(
              RemoteError(status.error.toString(), stackText),
              StackTrace.fromString(stackText),
            ),
          );
        }
      }
    });

    late final StreamSubscription<dynamic> commandSubscription;
    commandSubscription = commandPort.listen((message) {
      _handleCommand(message, executor, commandSubscription, commandPort, () {
        config.mainSendPort.send('stopped');
        Isolate.exit();
      });
    });

    // Isolate loop starts only after command port handshake is established.
    if (config.startPaused) {
      executor.pause();
    }
    executor.start();
  }

  static void _handleCommand(
    dynamic message,
    _LoopExecutor executor,
    StreamSubscription<dynamic> commandSubscription,
    ReceivePort commandPort,
    void Function() exit,
  ) {
    if (message == 'pause') {
      executor.pause();
    } else if (message == 'resume') {
      executor.resume();
    } else if (message == 'stop') {
      unawaited(
        executor.stop().then((_) async {
          await commandSubscription.cancel();
          commandPort.close();
          exit();
        }),
      );
    }
  }
}

class _IsolateConfig {
  final FutureOr<void> Function() body;
  final SendPort mainSendPort;
  final Duration? delay;
  final bool startPaused;

  _IsolateConfig(
    this.body,
    this.mainSendPort,
    this.delay, {
    this.startPaused = false,
  });
}
