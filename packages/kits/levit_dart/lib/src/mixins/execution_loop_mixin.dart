import 'dart:async';
import 'dart:isolate';

import 'package:levit_dart_core/levit_dart_core.dart';

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

/// A mixin for [LevitController] that manages background loops and stoppable services.
///
/// This mixin provides controller-scoped execution management with automatic cleanup.
mixin LevitExecutionLoopMixin on LevitController {
  final Map<String, StoppableService> _services = {};
  final Set<String> _permanentServices = {};

  /// Registers a [service] under [id].
  ///
  /// If a service with the same [id] already exists, it is stopped first.
  ///
  /// If [permanent] is true, the service will resist standard calls to [pauseAllServices].
  /// It will only be paused if [force] is set to true.
  /// However, even permanent services are stopped when the controller is closed.
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
  void onClose() {
    stopAllServices();
    super.onClose();
  }
}

class _LoopService implements StoppableService {
  final Future<void> Function() _body;
  final Duration? _delay;
  final _status = LxVar<LxStatus<dynamic>>(LxIdle());

  bool _isStopped = false;
  bool _isPaused = false;
  Completer<void>? _pauseCompleter;

  _LoopService(this._body, {Duration? delay}) : _delay = delay;

  @override
  LxReactive<LxStatus<dynamic>> get status => _status;

  @override
  void start() {
    if (_status.value is! LxIdle) return;
    _run();
  }

  @override
  void pause() {
    _isPaused = true;
    _status.value = LxWaiting();
  }

  @override
  void resume() {
    _isPaused = false;
    _pauseCompleter?.complete();
    _pauseCompleter = null;
    _status.value = LxWaiting();
  }

  @override
  void stop() {
    _isStopped = true;
    _resumeIfNeeded();
    _status.value = LxIdle();
  }

  void _resumeIfNeeded() {
    if (_pauseCompleter != null && !_pauseCompleter!.isCompleted) {
      _pauseCompleter!.complete();
    }
  }

  Future<void> _run() async {
    _status.value = LxWaiting();
    while (!_isStopped) {
      if (_isPaused) {
        _pauseCompleter = Completer<void>();
        await _pauseCompleter!.future;
        if (_isStopped) break;
      }

      try {
        await _body();
        _status.value = LxSuccess(null);
      } catch (e, s) {
        _status.value = LxError(e, s);
      }

      if (_delay != null && !_isStopped) {
        try {
          await Future.delayed(_delay!);
        } catch (_) {}
      }
    }
  }
}

class _IsolateLoopService implements StoppableService {
  final FutureOr<void> Function() _body;
  final Duration? _delay;
  final String? _debugName;
  final _status = LxVar<LxStatus<dynamic>>(LxIdle());

  SendPort? _commandPort;
  Isolate? _isolate;

  _IsolateLoopService(this._body, {Duration? delay, String? debugName})
      : _delay = delay,
        _debugName = debugName;

  @override
  LxReactive<LxStatus<dynamic>> get status => _status;

  @override
  void start() async {
    if (_status.value is! LxIdle) return;
    _status.value = LxWaiting();

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _isolateEntry,
      _IsolateConfig(_body, receivePort.sendPort, _delay),
      debugName: _debugName,
    );

    receivePort.listen((message) {
      if (message is SendPort) {
        _commandPort = message;
      } else if (message is LxStatus<dynamic>) {
        _status.value = message;
      }
    });
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
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _status.value = LxIdle();
  }

  static void _isolateEntry(_IsolateConfig config) async {
    final commandPort = ReceivePort();
    config.mainSendPort.send(commandPort.sendPort);

    bool isStopped = false;
    bool isPaused = false;
    Completer<void>? pauseCompleter;

    commandPort.listen((message) {
      if (message == 'pause') {
        isPaused = true;
      } else if (message == 'resume') {
        isPaused = false;
        pauseCompleter?.complete();
        pauseCompleter = null;
      } else if (message == 'stop') {
        isStopped = true;
        if (pauseCompleter != null && !pauseCompleter!.isCompleted) {
          pauseCompleter!.complete();
        }
      }
    });

    while (!isStopped) {
      if (isPaused) {
        pauseCompleter = Completer<void>();
        await pauseCompleter!.future;
        if (isStopped) break;
      }

      try {
        final result = config.body();
        if (result is Future) {
          await result;
        }
        config.mainSendPort.send(const LxSuccess(null));
      } catch (e, s) {
        config.mainSendPort.send(LxError(e, s));
      }

      if (config.delay != null && !isStopped) {
        await Future.delayed(config.delay!);
      }
    }
  }
}

class _IsolateConfig {
  final FutureOr<void> Function() body;
  final SendPort mainSendPort;
  final Duration? delay;

  _IsolateConfig(this.body, this.mainSendPort, this.delay);
}
