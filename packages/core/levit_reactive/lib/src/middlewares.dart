import 'base_types.dart';
import 'core.dart';

int _batchCounter = 0;

/// Represents a discrete change in a reactive variable's state.
///
/// [LevitReactiveChange] is passed to middlewares to allow inspection,
/// logging, or modification of the state transition.
class LevitReactiveChange<T> {
  /// The timestamp when the change was initiated.
  final DateTime timestamp;

  /// The runtime type of the value being changed.
  final Type valueType;

  /// The state of the variable before the change.
  final T oldValue;

  /// The proposed new state of the variable.
  final T newValue;

  /// The stack trace at the point of mutation (if enabled).
  final StackTrace? stackTrace;

  /// A function that restores the variable to its previous state.
  final void Function(dynamic value)? restore;

  /// Creates a record of a state change.
  LevitReactiveChange({
    required this.timestamp,
    required this.valueType,
    required this.oldValue,
    required this.newValue,
    this.stackTrace,
    this.restore,
  });

  bool _propagationStopped = false;

  /// Prevents subsequent middlewares from processing this specific change.
  void stopPropagation() {
    _propagationStopped = true;
  }

  /// Returns `true` if a middleware has stopped the propagation of this change.
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
class LevitReactiveBatch implements LevitReactiveChange<void> {
  /// The individual (reactive, change) pairs within this batch.
  final List<(LxReactive, LevitReactiveChange)> entries;

  /// A unique identifier for this batch execution.
  final int batchId;

  @override
  final DateTime timestamp;

  /// Creates a batch container for the current execution.
  LevitReactiveBatch(this.entries, {int? batchId})
      : batchId = batchId ?? ++_batchCounter,
        timestamp = DateTime.now();

  /// Legacy factory for constructing a batch from a list of changes.
  factory LevitReactiveBatch.fromChanges(List<LevitReactiveChange> changes) {
    return LevitReactiveBatch([]);
  }

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

/// Base class for intercepting and observing the reactive lifecycle.
///
/// Middlewares provide a unified way to implement cross-cutting concerns like
/// logging, state persistence, undo/redo, and analytics.
abstract class LevitReactiveMiddleware {
  /// Creates a [LevitReactiveMiddleware] instance.
  const LevitReactiveMiddleware();

  static final List<LevitReactiveMiddleware> _middlewares = [];

  static bool _hasSetMiddlewares = false;

  /// Returns `true` if any registered middleware has an [onSet] interceptor.
  static bool get hasSetMiddlewares => _hasSetMiddlewares;

  static bool _hasBatchMiddlewares = false;

  /// Returns `true` if any registered middleware has an [onBatch] interceptor.
  static bool get hasBatchMiddlewares => _hasBatchMiddlewares;

  static bool _hasDisposeMiddlewares = false;

  /// Returns `true` if any registered middleware has an [onDispose] interceptor.
  static bool get hasDisposeMiddlewares => _hasDisposeMiddlewares;

  static bool _hasInitMiddlewares = false;

  /// Returns `true` if any registered middleware has an [onInit] observer.
  static bool get hasInitMiddlewares => _hasInitMiddlewares;

  static bool _hasGraphChangeMiddlewares = false;

  /// Returns `true` if any registered middleware has an [onGraphChange] observer.
  static bool get hasGraphChangeMiddlewares => _hasGraphChangeMiddlewares;

  static void _updateFlags() {
    _hasSetMiddlewares = false;
    _hasBatchMiddlewares = false;
    _hasDisposeMiddlewares = false;
    _hasInitMiddlewares = false;
    _hasGraphChangeMiddlewares = false;

    for (final mw in _middlewares) {
      if (mw.onSet != null) _hasSetMiddlewares = true;
      if (mw.onBatch != null) _hasBatchMiddlewares = true;
      if (mw.onDispose != null) _hasDisposeMiddlewares = true;
      if (mw.onInit != null) _hasInitMiddlewares = true;
      if (mw.onGraphChange != null) _hasGraphChangeMiddlewares = true;
    }
  }

  /// Adds a middleware to the global registry.
  static LevitReactiveMiddleware add(LevitReactiveMiddleware middleware) {
    _middlewares.add(middleware);
    _updateFlags();
    return middleware;
  }

  /// Removes a middleware from the global registry.
  static bool remove(LevitReactiveMiddleware middleware) {
    final result = _middlewares.remove(middleware);
    _updateFlags();
    return result;
  }

  /// Clears all currently registered middlewares.
  static void clear() {
    _middlewares.clear();
    _updateFlags();
  }

  /// Returns `true` if the middleware is currently registered.
  static bool contains(LevitReactiveMiddleware middleware) {
    return _middlewares.contains(middleware);
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

  /// Intercepts and optionally wraps a value mutation.
  LxOnSet? get onSet => null;

  /// Intercepts and optionally wraps a batch execution.
  LxOnBatch? get onBatch => null;

  /// Intercepts and optionally wraps the disposal of a reactive object.
  LxOnDispose? get onDispose => null;

  /// Observes the initialization of a reactive object.
  void Function(LxReactive reactive)? get onInit => null;

  /// Observes dependencies change in a computed reactive object.
  void Function(LxReactive computed, List<LxReactive> dependencies)?
      get onGraphChange => null;
}

/// Helper typedefs for middleware interception.
typedef LxOnSet = void Function(dynamic value) Function(
  void Function(dynamic value) next,
  LxReactive reactive,
  LevitReactiveChange<dynamic> change,
);

/// Helper typedefs for middleware interception.
typedef LxOnBatch = dynamic Function() Function(
  dynamic Function() next,
  LevitReactiveBatch change,
);

/// Helper typedefs for middleware interception.
typedef LxOnDispose = void Function() Function(
  void Function() next,
  LxReactive reactive,
);

/// Internal utility for applying the middleware chain.
abstract class LevitStateMiddlewareChain {
  /// Applies the [onSet] chain to a value mutation.
  static void Function(T) applyOnSet<T>(
    void Function(T) next,
    LxReactive reactive,
    LevitReactiveChange<T> change,
  ) {
    if (!LevitReactiveMiddleware.hasSetMiddlewares) return next;

    void Function(dynamic) current = (dynamic v) => next(v as T);

    for (final mw in LevitReactiveMiddleware._middlewares.reversed) {
      if (mw.onSet != null) {
        current = mw.onSet!(
            current, reactive, change as LevitReactiveChange<dynamic>);
      }
    }

    return (T val) => current(val);
  }

  /// Applies the [onBatch] chain to a batch operation.
  static dynamic Function() applyOnBatch(
    dynamic Function() next,
    LevitReactiveBatch change,
  ) {
    if (!LevitReactiveMiddleware.hasBatchMiddlewares) return next;
    var current = next;
    for (final mw in LevitReactiveMiddleware._middlewares.reversed) {
      if (mw.onBatch != null) {
        current = mw.onBatch!(current, change);
      }
    }
    return current;
  }

  /// Applies the [onDispose] chain to a reactive object disposal.
  static void Function() applyOnDispose(
    void Function() next,
    LxReactive reactive,
  ) {
    if (!LevitReactiveMiddleware.hasDisposeMiddlewares) return next;
    var current = next;
    for (final mw in LevitReactiveMiddleware._middlewares.reversed) {
      if (mw.onDispose != null) {
        current = mw.onDispose!(current, reactive);
      }
    }
    return current;
  }

  /// Notifies middlewares of a reactive object initialization.
  static void applyOnInit(LxReactive reactive) {
    if (!LevitReactiveMiddleware.hasInitMiddlewares) return;
    for (final mw in LevitReactiveMiddleware._middlewares) {
      mw.onInit?.call(reactive);
    }
  }

  /// Notifies middlewares of a dependency graph change.
  static void applyGraphChange(
    LxReactive computed,
    List<LxReactive> dependencies,
  ) {
    if (!LevitReactiveMiddleware.hasGraphChangeMiddlewares) return;
    for (final mw in LevitReactiveMiddleware._middlewares) {
      mw.onGraphChange?.call(computed, dependencies);
    }
  }
}

/// A standard middleware for recording the state history.
class LevitReactiveHistoryMiddleware extends LevitReactiveMiddleware {
  /// The maximum number of changes to keep in the undo stack.
  static int maxHistorySize = 100;

  final List<LevitReactiveChange> _undoStack = [];
  final List<LevitReactiveChange> _redoStack = [];
  final _version = LxVar(0);

  bool _isRestoring = false;

  /// Creates a history tracking middleware.
  LevitReactiveHistoryMiddleware();

  /// Returns an unmodifiable list of all recorded changes in the undo stack.
  List<LevitReactiveChange> get changes {
    _version.value;
    return List.unmodifiable(_undoStack);
  }

  /// Returns an unmodifiable list of changes available for redo.
  List<LevitReactiveChange> get redoChanges {
    _version.value;
    return List.unmodifiable(_redoStack);
  }

  /// The number of recorded changes in the undo stack.
  int get length {
    _version.value;
    return _undoStack.length;
  }

  /// Whether there are changes available to undo.
  bool get canUndo {
    _version.value;
    return _undoStack.isNotEmpty;
  }

  /// Whether there are changes available to redo.
  bool get canRedo {
    _version.value;
    return _redoStack.isNotEmpty;
  }

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        return (value) {
          next(value);
          if (_isRestoring) return;
          _redoStack.clear();
          if (_batchDepth == 0) _addChange(change);
        };
      };

  int _batchDepth = 0;

  @override
  LxOnBatch? get onBatch => (next, change) {
        return () {
          if (_isRestoring) return next();
          _batchDepth++;
          try {
            return next();
          } finally {
            _batchDepth--;
            if (_batchDepth == 0 && change.isNotEmpty) _addChange(change);
          }
        };
      };

  void _addChange(LevitReactiveChange change) {
    _undoStack.add(change);
    if (maxHistorySize > 0 && _undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
    LevitReactiveMiddleware.runWithoutMiddleware(() => _version.value++);
  }

  /// Reverts the most recent state change.
  bool undo() {
    if (_undoStack.isEmpty) return false;
    final change = _undoStack.removeLast();
    _redoStack.add(change);
    _applyRestore(change, isUndo: true);
    LevitReactiveMiddleware.runWithoutMiddleware(() => _version.value++);
    return true;
  }

  /// Re-applies the most recent undone state change.
  bool redo() {
    if (_redoStack.isEmpty) return false;
    final change = _redoStack.removeLast();
    _undoStack.add(change);
    _applyRestore(change, isUndo: false);
    LevitReactiveMiddleware.runWithoutMiddleware(() => _version.value++);
    return true;
  }

  void _applyRestore(LevitReactiveChange change, {required bool isUndo}) {
    _isRestoring = true;
    try {
      if (change is LevitReactiveBatch) {
        final list = isUndo ? change.changes.reversed : change.changes;
        for (final sub in list) {
          _restoreSingle(sub, isUndo: isUndo);
        }
      } else {
        _restoreSingle(change, isUndo: isUndo);
      }
    } finally {
      _isRestoring = false;
    }
  }

  void _restoreSingle(LevitReactiveChange change, {required bool isUndo}) {
    final valueToRestore = isUndo ? change.oldValue : change.newValue;
    if (change.restore != null) {
      LevitReactiveMiddleware.runWithoutMiddleware(() {
        change.restore!(valueToRestore);
      });
    }
  }

  /// Clears the history state.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    LevitReactiveMiddleware.runWithoutMiddleware(() => _version.value++);
  }

  /// Returns all changes of a specific type.
  List<LevitReactiveChange> changesOfType(Type type) {
    return _undoStack.where((c) => c.valueType == type).toList();
  }

  /// Prints the current history to the console for debugging.
  void printHistory() {
    print('--- Undo Stack ---');
    for (final change in _undoStack) {
      print(change);
    }
    if (_redoStack.isNotEmpty) {
      print('--- Redo Stack ---');
      for (final change in _redoStack.reversed) {
        print(change);
      }
    }
  }
}
