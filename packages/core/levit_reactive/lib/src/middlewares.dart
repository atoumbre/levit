part of 'reactive_library.dart';

int _batchCounter = 0;

/// Represents a state transition in a reactive variable.
///
/// Captured by [LevitReactiveMiddleware] to support logging, debugging,
/// and undo/redo operations.
///
/// {@category Middleware & Monitoring}
class LevitReactiveChange<T> {
  /// The timestamp of the change, computed lazily on first access.
  DateTime get timestamp => _timestamp ??= DateTime.now();
  DateTime? _timestamp;

  /// The runtime type of the value held.
  final Type valueType;

  /// The value before modification.
  final T oldValue;

  /// The value after modification.
  final T newValue;

  /// The stack trace at the moment of change, if enabled.
  final StackTrace? stackTrace;

  /// A callback that writes a supplied `value` back to the reactive variable.
  ///
  /// Call `restore?.call(oldValue)` to undo or `restore?.call(newValue)` to redo.
  final void Function(dynamic value)? restore;

  /// Creates a record of a state change.
  LevitReactiveChange({
    DateTime? timestamp,
    required this.valueType,
    required this.oldValue,
    required this.newValue,
    this.stackTrace,
    this.restore,
  }) : _timestamp = timestamp;

  bool _propagationStopped = false;

  /// Marks this change as handled for cooperative downstream middlewares.
  ///
  /// The middleware chain does not skip subsequent middlewares automatically;
  /// downstream middlewares should inspect [isPropagationStopped], or an
  /// intercepting middleware can omit calling `next` to short-circuit execution.
  void stopPropagation() {
    _propagationStopped = true;
  }

  /// Returns `true` if a middleware called [stopPropagation] on this change.
  bool get isPropagationStopped => _propagationStopped;

  @override
  String toString() {
    return '[$timestamp] $valueType: $oldValue → $newValue';
  }
}

/// A collection of [LevitReactiveChange]s captured during a batch operation.
///
/// Implements [LevitReactiveChange] to allow composite observation of multiple
/// simultaneous state transitions.
///
/// {@category Middleware & Monitoring}
class LevitReactiveBatch implements LevitReactiveChange<void> {
  /// The individual (reactive, change) pairs within this batch.
  final List<(LxReactive, LevitReactiveChange)> entries;

  /// A unique identifier for this batch execution.
  final int batchId;

  /// Whether this boundary remains open until its returned future completes.
  /// Synchronous batches close when their callback returns, even a Future.
  final bool isAsync;

  DateTime? _timestamp;

  @override
  DateTime get timestamp => _timestamp ??= DateTime.now();

  /// Creates a batch container for the current execution.
  LevitReactiveBatch(
    this.entries, {
    int? batchId,
    DateTime? timestamp,
    this.isAsync = false,
  }) : batchId = batchId ?? ++_batchCounter,
       _timestamp = timestamp;

  /// Returns just the list of state changes from the batch.
  List<LevitReactiveChange> get changes => entries.map((e) => e.$2).toList();

  /// Returns just the list of reactive variables involved in the batch.
  List<LxReactive> get reactiveVariables => entries.map((e) => e.$1).toList();

  /// The number of changes captured in this batch.
  int get length => entries.length;

  /// Returns `true` if the batch contains no changes.
  bool get isEmpty => entries.isEmpty;

  /// Returns `true` if the batch contains one or more changes.
  bool get isNotEmpty => entries.isNotEmpty;

  @override
  Type get valueType => LevitReactiveBatch;

  @override
  void get oldValue {}

  @override
  void get newValue {}

  @override
  StackTrace? get stackTrace => null;

  @override
  void Function(dynamic value)? get restore => null;

  @override
  bool _propagationStopped = false;

  @override
  void stopPropagation() {
    _propagationStopped = true;
  }

  @override
  bool get isPropagationStopped => _propagationStopped;

  @override
  String toString() => '[$timestamp] Batch of ${entries.length} changes';
}

/// Base class for intercepting reactive system events.
///
/// Implement this class to create cross-cutting tools like loggers,
/// dev-tools, or state synchronization plugins.
///
/// You can intercept:
/// *   State changes ([onSet], [onBatch])
/// *   Lifecycle events ([onInit], [onDispose])
/// *   Graph updates ([onGraphChange])
/// *   Listener activity ([startedListening], [stoppedListening])
/// *   Errors ([onReactiveError])
///
/// {@category Middleware & Monitoring}
abstract class LevitReactiveMiddleware {
  /// Base constructor.
  const LevitReactiveMiddleware();

  static final List<LevitReactiveMiddleware> _middlewares = [];
  static final Map<Object, LevitReactiveMiddleware> _middlewaresByToken = {};

  static bool _hasSetMiddlewares = false;
  static bool _hasBatchMiddlewares = false;
  static bool _hasDisposeMiddlewares = false;
  static bool _hasInitMiddlewares = false;
  static bool _hasGraphChangeMiddlewares = false;
  static bool _hasListenerMiddlewares = false;
  static bool _hasErrorMiddlewares = false;

  static void _updateFlags() {
    _hasSetMiddlewares = false;
    _hasBatchMiddlewares = false;
    _hasDisposeMiddlewares = false;
    _hasInitMiddlewares = false;
    _hasGraphChangeMiddlewares = false;
    _hasListenerMiddlewares = false;
    _hasErrorMiddlewares = false;

    for (final mw in _middlewares) {
      if (mw.onSet != null) _hasSetMiddlewares = true;
      if (mw.onBatch != null) _hasBatchMiddlewares = true;
      if (mw.onDispose != null) _hasDisposeMiddlewares = true;
      if (mw.onInit != null) _hasInitMiddlewares = true;
      if (mw.onGraphChange != null) _hasGraphChangeMiddlewares = true;
      if (mw.startedListening != null || mw.stoppedListening != null) {
        _hasListenerMiddlewares = true;
      }
      if (mw.onReactiveError != null) _hasErrorMiddlewares = true;
    }
  }

  /// Adds a middleware to the global registry.
  ///
  /// Registration is idempotent by instance identity.
  /// If [token] is provided, registration is unique per token:
  /// adding another middleware with the same token replaces the previous one.
  static LevitReactiveMiddleware add(
    LevitReactiveMiddleware middleware, {
    Object? token,
  }) {
    if (token == null) return _addUntokened(middleware);

    final existingByToken = _middlewaresByToken[token];
    if (identical(existingByToken, middleware)) return middleware;

    if (existingByToken != null) {
      return _replaceTokenized(token, existingByToken, middleware);
    }

    if (_middlewares.contains(middleware)) {
      return _attachToken(token, middleware);
    }

    return _addTokenized(token, middleware);
  }

  static LevitReactiveMiddleware _addUntokened(
    LevitReactiveMiddleware middleware,
  ) {
    if (_middlewares.contains(middleware)) return middleware;

    _middlewares.add(middleware);
    _updateFlags();
    return middleware;
  }

  static LevitReactiveMiddleware _attachToken(
    Object token,
    LevitReactiveMiddleware middleware,
  ) {
    _middlewaresByToken[token] = middleware;
    return middleware;
  }

  static LevitReactiveMiddleware _addTokenized(
    Object token,
    LevitReactiveMiddleware middleware,
  ) {
    _middlewares.add(middleware);
    _middlewaresByToken[token] = middleware;
    _updateFlags();
    return middleware;
  }

  static LevitReactiveMiddleware _replaceTokenized(
    Object token,
    LevitReactiveMiddleware existingByToken,
    LevitReactiveMiddleware middleware,
  ) {
    final index = _middlewares.indexOf(existingByToken);
    if (index >= 0) _middlewares[index] = middleware;
    if (index < 0) _middlewares.add(middleware);
    _middlewaresByToken[token] = middleware;
    _updateFlags();
    return middleware;
  }

  /// Removes a middleware from the global registry.
  static bool remove(LevitReactiveMiddleware middleware) {
    final result = _middlewares.remove(middleware);
    if (result) {
      _middlewaresByToken.removeWhere(
        (_, registered) => identical(registered, middleware),
      );
      _updateFlags();
    }
    return result;
  }

  /// Removes a middleware by [token].
  static bool removeByToken(Object token) {
    final middleware = _middlewaresByToken.remove(token);
    if (middleware == null) return false;

    return _removeByTokenizedMiddleware(middleware);
  }

  static bool _removeByTokenizedMiddleware(LevitReactiveMiddleware middleware) {
    final removed = _middlewares.remove(middleware);
    if (removed) {
      _updateFlags();
    }
    return removed;
  }

  /// Clears all currently registered middlewares.
  static void clear() {
    _middlewares.clear();
    _middlewaresByToken.clear();
    _updateFlags();
  }

  /// Returns `true` if the middleware is currently registered.
  static bool contains(LevitReactiveMiddleware middleware) {
    return _middlewares.contains(middleware);
  }

  /// Returns `true` if [token] is currently registered.
  static bool containsToken(Object token) {
    return _middlewaresByToken.containsKey(token);
  }

  static bool _bypassMiddleware = false;

  /// Returns `true` if middlewares are currently being bypassed.
  static bool get bypassMiddleware => _bypassMiddleware;

  /// Bypasses all middlewares for the duration of [action].
  static void runWithoutMiddleware(void Function() action) {
    final prev = _bypassMiddleware;
    _bypassMiddleware = true;
    try {
      action();
    } finally {
      _bypassMiddleware = prev;
    }
  }

  /// Intercepts value mutations.
  ///
  /// Return a wrapped function to modify or log the set operation.
  LevitReactiveOnSet? get onSet => null;

  /// Intercepts batch operations. Await completion only when
  /// [LevitReactiveBatch.isAsync] is `true`; synchronous boundaries close on return.
  LevitReactiveOnBatch? get onBatch => null;

  /// Intercepts disposal.
  LevitReactiveOnDispose? get onDispose => null;

  /// Observes initialization of new reactive objects.
  void Function(LxReactive reactive)? get onInit => null;

  /// Observes changes to the dependency graph of a computed value.
  void Function(LxReactive computed, List<LxReactive> dependencies)?
  get onGraphChange => null;

  /// Observes when a new listener is added.
  void Function(LxReactive reactive, LxListenerContext? context)?
  get startedListening => null;

  /// Observes when a listener is removed.
  void Function(LxReactive reactive, LxListenerContext? context)?
  get stoppedListening => null;

  /// Observes errors caught during notification.
  void Function(Object error, StackTrace? stack, LxReactive? context)?
  get onReactiveError => null;
}

/// Function signature for [LevitReactiveMiddleware.onSet] wrappers.
///
/// {@category Middleware & Monitoring}
typedef LevitReactiveOnSet =
    void Function(dynamic value) Function(
      void Function(dynamic value) next,
      LxReactive reactive,
      LevitReactiveChange<dynamic> change,
    );

/// Function signature for [LevitReactiveMiddleware.onBatch] wrappers.
///
/// {@category Middleware & Monitoring}
typedef LevitReactiveOnBatch =
    dynamic Function() Function(
      dynamic Function() next,
      LevitReactiveBatch change,
    );

/// Function signature for [LevitReactiveMiddleware.onDispose] wrappers.
///
/// {@category Middleware & Monitoring}
typedef LevitReactiveOnDispose =
    void Function() Function(void Function() next, LxReactive reactive);

/// Internal utility for applying the middleware chain.
abstract class _LevitReactiveMiddlewareChain {
  /// Applies the [LevitReactiveMiddleware.onSet] chain to a value mutation.
  static void Function(T) applyOnSet<T>(
    void Function(T) next,
    LxReactive reactive,
    LevitReactiveChange<T> change,
  ) {
    if (!LevitReactiveMiddleware._hasSetMiddlewares) return next;

    void Function(dynamic) current = (dynamic v) => next(v as T);
    final middlewares = LevitReactiveMiddleware._middlewares;

    for (var i = middlewares.length - 1; i >= 0; i--) {
      final hook = middlewares[i].onSet;
      if (hook != null) {
        current = hook(
          current,
          reactive,
          change as LevitReactiveChange<dynamic>,
        );
      }
    }

    return (T val) => current(val);
  }

  /// Applies the [LevitReactiveMiddleware.onBatch] chain to a batch operation.
  static dynamic Function() applyOnBatch(
    dynamic Function() next,
    LevitReactiveBatch change,
  ) {
    if (!LevitReactiveMiddleware._hasBatchMiddlewares) return next;
    var current = next;
    final middlewares = LevitReactiveMiddleware._middlewares;
    for (var i = middlewares.length - 1; i >= 0; i--) {
      final hook = middlewares[i].onBatch;
      if (hook != null) {
        current = hook(current, change);
      }
    }
    return current;
  }

  /// Applies the [LevitReactiveMiddleware.onDispose] chain to a reactive object disposal.
  static void Function() applyOnDispose(
    void Function() next,
    LxReactive reactive,
  ) {
    if (!LevitReactiveMiddleware._hasDisposeMiddlewares) return next;
    var current = next;
    final middlewares = LevitReactiveMiddleware._middlewares;
    for (var i = middlewares.length - 1; i >= 0; i--) {
      final hook = middlewares[i].onDispose;
      if (hook != null) {
        current = hook(current, reactive);
      }
    }
    return current;
  }

  /// Notifies middlewares of a reactive object initialization.
  static void applyOnInit(LxReactive reactive) {
    if (!LevitReactiveMiddleware._hasInitMiddlewares) return;
    final middlewares = LevitReactiveMiddleware._middlewares;
    for (var i = 0; i < middlewares.length; i++) {
      middlewares[i].onInit?.call(reactive);
    }
  }

  /// Notifies middlewares of a dependency graph change.
  static void applyGraphChange(
    LxReactive computed,
    List<LxReactive> dependencies,
  ) {
    if (!LevitReactiveMiddleware._hasGraphChangeMiddlewares) return;
    final middlewares = LevitReactiveMiddleware._middlewares;
    for (var i = 0; i < middlewares.length; i++) {
      middlewares[i].onGraphChange?.call(computed, dependencies);
    }
  }

  /// Notifies middlewares that a listener has been added.
  static void applyOnListenerAdd(
    LxReactive reactive,
    LxListenerContext? context,
  ) {
    if (!LevitReactiveMiddleware._hasListenerMiddlewares) {
      return;
    }
    final middlewares = LevitReactiveMiddleware._middlewares;
    for (var i = 0; i < middlewares.length; i++) {
      middlewares[i].startedListening?.call(reactive, context);
    }
  }

  /// Notifies middlewares that a listener has been removed.
  static void applyOnListenerRemove(
    LxReactive reactive,
    LxListenerContext? context,
  ) {
    if (!LevitReactiveMiddleware._hasListenerMiddlewares) return;
    final middlewares = LevitReactiveMiddleware._middlewares;
    for (var i = 0; i < middlewares.length; i++) {
      middlewares[i].stoppedListening?.call(reactive, context);
    }
  }

  /// Notifies middlewares that an error occurred.
  static void applyOnReactiveError(
    Object error,
    StackTrace? stack,
    LxReactive? context,
  ) {
    if (!LevitReactiveMiddleware._hasErrorMiddlewares) return;
    final middlewares = LevitReactiveMiddleware._middlewares;
    for (var i = 0; i < middlewares.length; i++) {
      middlewares[i].onReactiveError?.call(error, stack, context);
    }
  }
}

/// Optional SPI observer for reactive metadata mutations (`name`, `ownerId`,
/// `isSensitive`), independent of value notifications.
///
/// Implement on a [LevitReactiveMiddleware] registered via `Lx.addMiddleware`
/// (or `Levit.addStateMiddleware`).
///
/// {@category SPI}
abstract interface class LevitReactiveMetadataObserver {
  /// Called when metadata (`name`, `ownerId`, or `isSensitive`) changes on
  /// [reactive].
  void onReactiveMetadata(LxReactive reactive);
}
