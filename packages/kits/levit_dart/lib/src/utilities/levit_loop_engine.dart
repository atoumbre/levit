part of '../../levit_dart.dart';

/// A service that can be started, paused, resumed, and stopped.
///
/// It exposes a reactive [status] for state tracking and error reporting.
abstract class StoppableService {
  /// Reactive status of the service.
  LxReactive<LxStatus<dynamic>> get status;

  /// Starts the service.
  void start();

  /// Pauses the service.
  void pause();

  /// Resumes the service.
  void resume();

  /// Stops the service gracefully.
  void stop();
}

/// A standalone execution engine for managing repetitive loops and long-running services.
///
/// It supports:
/// *   Sequential loop execution with delays.
/// *   Isolate-based loops for heavy background work.
/// *   Centralized start/pause/resume/stop control for all registered services.
class LevitLoopEngine implements LevitDisposable {
  final Map<String, StoppableService> _services = {};
  final Set<String> _permanentServices = {};

  /// Registers a [service] under [id].
  ///
  /// If a service with the same [id] already exists, it is stopped first.
  ///
  /// If [permanent] is true, the service will resist standard calls to [pauseAllServices].
  /// It will only be paused if [force] is set to true.
  /// However, even permanent services are stopped when the engine is disposed.
  T registerService<T extends StoppableService>(
    String id,
    T service, {
    bool permanent = false,
  }) {
    _services[id]?.stop();
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
    final service = _LoopService(body, delay: delay);
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
    final service =
        _IsolateLoopService(body, delay: delay, debugName: debugName);
    registerService(id, service, permanent: permanent);
    service.start();
  }

  /// Pauses the service with the given [id].
  void pauseService(String id) => _services[id]?.pause();

  /// Resumes the service with the given [id].
  void resumeService(String id) => _services[id]?.resume();

  /// Stops the service with the given [id].
  void stopService(String id) {
    _services[id]?.stop();
    _services.remove(id);
    _permanentServices.remove(id);
  }

  /// Pauses all registered services.
  ///
  /// If [force] is true, pauses all services including permanent ones.
  /// If [force] is false (default), pauses only non-permanent services.
  void pauseAllServices({bool force = false}) {
    for (final entry in _services.entries) {
      if (force || !_permanentServices.contains(entry.key)) {
        entry.value.pause();
      }
    }
  }

  /// Resumes all registered services.
  ///
  /// If [force] is true, resumes all services including permanent ones.
  /// If [force] is false (default), resumes only non-permanent services.
  void resumeAllServices({bool force = false}) {
    for (final entry in _services.entries) {
      if (force || !_permanentServices.contains(entry.key)) {
        entry.value.resume();
      }
    }
  }

  /// Stops all registered services.
  ///
  /// This stops EVERYTHING, regardless of permanent status.
  void stopAllServices() {
    for (final service in _services.values) {
      service.stop();
    }
    _services.clear();
    _permanentServices.clear();
  }

  /// Returns the status of the service with the given [id], or null if not found.
  LxReactive<LxStatus<dynamic>>? getServiceStatus(String id) =>
      _services[id]?.status;

  @override
  void dispose() {
    stopAllServices();
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
  LxStatus<dynamic> _lastStatus = LxIdle();

  _LoopExecutor(this._body, this._delay, this._onStatusChanged);

  void start() {
    if (_lastStatus is! LxIdle) return;
    _run();
  }

  void pause() {
    _isPaused = true;
    _updateStatus(LxWaiting());
  }

  void resume() {
    _isPaused = false;
    _pauseCompleter?.complete();
    _pauseCompleter = null;
    _updateStatus(LxWaiting());
  }

  void stop() {
    _isStopped = true;
    if (_pauseCompleter != null && !_pauseCompleter!.isCompleted) {
      _pauseCompleter!.complete();
    }
    _updateStatus(LxIdle());
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

      if (_delay != null && !_isStopped) {
        try {
          await Future.delayed(_delay!);
        } catch (_) {}
      }
    }
  }
}

class _LoopService implements StoppableService {
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
  void stop() => _executor.stop();
}

class _IsolateLoopService implements StoppableService {
  final FutureOr<void> Function() _body;
  final Duration? _delay;
  final String? _debugName;
  final _status = LxVar<LxStatus<dynamic>>(LxIdle());

  SendPort? _commandPort;
  Isolate? _isolate;
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _receiveSubscription;

  _IsolateLoopService(this._body, {Duration? delay, String? debugName})
      : _delay = delay,
        _debugName = debugName;

  @override
  LxReactive<LxStatus<dynamic>> get status => _status;

  @override
  void start() {
    if (_status.value is! LxIdle) return;
    unawaited(_start());
  }

  Future<void> _start() async {
    _status.value = LxWaiting();

    await _closeReceivePort();
    try {
      _receivePort = ReceivePort();
      _receiveSubscription = _receivePort!.listen(
        (message) {
          if (message is SendPort) {
            _commandPort = message;
          } else if (message is LxStatus<dynamic>) {
            _status.value = message;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _status.value = LxError(error, stackTrace);
        },
      );

      final isolate = await Isolate.spawn(
        _isolateEntry,
        _IsolateConfig(_body, _receivePort!.sendPort, _delay),
        debugName: _debugName,
      );

      if (_status.value is LxIdle) {
        isolate.kill(priority: Isolate.beforeNextEvent);
        await _closeReceivePort();
        return;
      }
      _isolate = isolate;
    } catch (e, s) {
      _status.value = LxError(e, s);
      await _closeReceivePort();
    }
  }

  @override
  void pause() {
    _commandPort?.send('pause');
    _status.value = LxWaiting();
  }

  @override
  void resume() {
    _commandPort?.send('resume');
    _status.value = LxWaiting();
  }

  @override
  void stop() {
    _commandPort?.send('stop');
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _commandPort = null;
    _isolate = null;
    unawaited(_closeReceivePort());
    _status.value = LxIdle();
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

    final executor = _LoopExecutor(
      config.body,
      config.delay,
      (status) => config.mainSendPort.send(status),
    );

    late final StreamSubscription<dynamic> commandSubscription;
    commandSubscription = commandPort.listen((message) {
      if (message == 'pause') {
        executor.pause();
      } else if (message == 'resume') {
        executor.resume();
      } else if (message == 'stop') {
        executor.stop();
        commandSubscription.cancel();
        commandPort.close();
        Isolate.exit();
      }
    });

    // Start the executor directly
    executor.start();
  }
}

class _IsolateConfig {
  final FutureOr<void> Function() body;
  final SendPort mainSendPort;
  final Duration? delay;

  _IsolateConfig(this.body, this.mainSendPort, this.delay);
}
