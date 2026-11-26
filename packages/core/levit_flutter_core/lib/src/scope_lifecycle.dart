part of '../levit_flutter_core.dart';

/// Coordinates scope replacement and exposes completion beyond widget disposal.
/// A controller belongs to one scope widget for that widget's lifetime.
/// Initialization is tracked before user callbacks run, including reentrant
/// replacement requests. Listener-triggered close still awaits resource drain.
///
/// {@category Flutter Widgets & Interop}
class LevitScopeLifecycleController implements Listenable {
  final _ScopeChanges _changes = _ScopeChanges();
  final Completer<void> _closed = Completer<void>();
  LevitScope? _scope;
  _ScopeRequest? _pending;
  _ScopeRequest? _lastRequest;
  bool _running = false;
  bool _closing = false;
  bool _ready = false;
  int _generation = 0;
  Future<void> _settled = Future<void>.value();
  Object? _error;
  StackTrace? _stackTrace;
  Object? _cleanupError;
  StackTrace? _cleanupStack;

  /// The active [LevitScope], published only after initialization succeeds and
  /// while not closing; otherwise `null`.
  LevitScope? get scope => isReady ? _scope : null;

  /// Whether a scope is initialized and actively available via [scope].
  bool get isReady => _ready && !(_scope?.isClosing ?? true);

  /// Whether a scope replacement or initialization is currently running.
  bool get isLoading => _running && !_closing;

  /// The latest initialization or cleanup failure, if any.
  Object? get error => _error;

  /// The stack trace associated with [error], if any.
  StackTrace? get stackTrace => _stackTrace;

  /// Completes once all currently requested replacements have settled.
  /// Inspect [error] to distinguish readiness from a failed transition.
  Future<void> get settled => _settled;

  /// Completes once terminal cleanup finishes. Await [close] for errors.
  Future<void> get closed => _closed.future;

  @override
  void addListener(VoidCallback listener) => _changes.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      _changes.removeListener(listener);

  /// Serializes scope replacement under [parent] with [name] and [initialize],
  /// coalescing rapid requests to the latest configuration.
  ///
  /// Throws a [StateError] if [close] has already started. If a prior cleanup
  /// error is latched, subsequent [replace] calls keep surfacing that error
  /// until [retry] is called.
  Future<void> replace({
    required LevitScope parent,
    required String name,
    required FutureOr<void> Function(LevitScope scope) initialize,
  }) {
    if (_closing) throw StateError('Scope lifecycle is closing.');
    _lastRequest = _ScopeRequest(parent, name, initialize);
    if (_cleanupError != null) {
      _error = _cleanupError;
      _stackTrace = _cleanupStack;
      return settled;
    }
    _pending = _lastRequest;
    _generation++;
    _ready = false;
    _scope?.requestCancel();
    _error = null;
    _stackTrace = null;
    _start();
    return settled;
  }

  /// Clears any latched cleanup error and retries the latest configuration.
  ///
  /// Throws a [StateError] if closing or if [replace] has never been called.
  Future<void> retry() {
    if (_closing) throw StateError('Scope lifecycle is closing.');
    final request = _lastRequest;
    if (request == null) throw StateError('No scope configuration to retry.');
    _cleanupError = null;
    _cleanupStack = null;
    return replace(
      parent: request.parent,
      name: request.name,
      initialize: request.initialize,
    );
  }

  void _start() {
    if (_running) return;
    _running = true;
    final completion = Completer<void>();
    _settled = completion.future;
    unawaited(_runPump(completion));
  }

  Future<void> _runPump(Completer<void> completion) async {
    try {
      await _pump();
      while (_cleanupError == null &&
          (_pending != null || (_closing && _scope != null))) {
        await _pump();
      }
    } catch (error, stack) {
      // Generation initialization errors are handled by _pump. A release
      // failure, including one from a coalesced request, stops replacement.
      _cleanupError = _error = error;
      _cleanupStack = _stackTrace = stack;
    } finally {
      _running = false;
      try {
        _changes.publish();
      } finally {
        completion.complete();
        // A listener may start terminal cleanup from this idle notification.
        // That new pump owns completion; it must drain before closed resolves.
        if (_closing && !_running && _scope == null && !_closed.isCompleted) {
          _closed.complete();
        }
      }
    }
  }

  Future<void> _release() async {
    final previous = _scope;
    _scope = null;
    if (previous != null) await previous.dispose();
  }

  Future<void> _pump() async {
    while (true) {
      if (_cleanupError != null) return;
      if (_scope != null) await _release();
      if (_closing || _pending == null) return;
      final request = _pending!;
      _pending = null;
      final generation = _generation;
      LevitScope? created;
      try {
        created = request.parent.createScope(request.name);
        _scope = created;
        // Record admission before invoking user code: it may synchronously
        // request replacement or close before returning its future.
        final initializingScope = created;
        final initialization = created.runInitialization<void>(
          () => request.initialize(initializingScope),
        );
        if (initialization is Future) await initialization;
        if (generation == _generation && !_closing && !created.isClosing) {
          _ready = true;
          _changes.publish();
          return;
        }
      } catch (error, stack) {
        if (generation == _generation && !_closing) {
          _error = error;
          _stackTrace = stack;
          await _release();
          return;
        }
      }
      // A stale initializer can only retire its own captured generation.
    }
  }

  /// Initiates terminal cleanup and waits for initialization and resource drain.
  Future<void> close() async {
    _scope?.assertCanDispose();
    if (!_closing) {
      _closing = true;
      _ready = false;
      _pending = null;
      _generation++;
      _scope?.requestCancel();
      _start();
    }
    await closed;
    if (_cleanupError != null) {
      Error.throwWithStackTrace(_cleanupError!, _cleanupStack!);
    }
  }
}

class _ScopeRequest {
  const _ScopeRequest(this.parent, this.name, this.initialize);
  final LevitScope parent;
  final String name;
  final FutureOr<void> Function(LevitScope scope) initialize;
}

void _reportScopeCleanupError(Object error, StackTrace stack) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'levit_flutter_core',
      context: ErrorDescription('while closing a widget-owned Levit scope'),
    ),
  );
}

class _ScopeChanges extends ChangeNotifier {
  void publish() => notifyListeners();
}
