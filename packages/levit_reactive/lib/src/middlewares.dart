import 'package:meta/meta.dart';

import 'base_types.dart';
import 'core.dart';

// ============================================================================
// Middleware / Interceptor Pattern for Debugging
// ============================================================================

int _batchCounter = 0;

/// Counter for generating unique batch IDs within this session.

/// Represents a change in a reactive variable's state.
///
/// Passed to [LevitStateMiddleware] to inspect or modify state changes.
class LevitStateChange<T> {
  /// Time of the change.
  final DateTime timestamp;

  /// Type of the value.
  final Type valueType;

  /// Previous value.
  final T oldValue;

  /// New value.
  final T newValue;

  /// Stack trace (if enabled).
  final StackTrace? stackTrace;

  /// Function to restore this state (for undo).
  final void Function(dynamic value)? restore;

  /// Creates a state change record.
  LevitStateChange({
    required this.timestamp,
    required this.valueType,
    required this.oldValue,
    required this.newValue,
    this.stackTrace,
    this.restore,
  });

  bool _propagationStopped = false;

  /// Stops propagation to subsequent middlewares.
  void stopPropagation() {
    _propagationStopped = true;
  }

  /// Whether propagation is stopped.
  bool get isPropagationStopped => _propagationStopped;

  @override
  String toString() {
    return '[$timestamp] $valueType: $oldValue → $newValue';
  }
}

/// A batch of state changes grouped together.
///
/// Used when [Lx.batch] is active. Contains pairs of reactive variables
/// and their associated state changes.
class LevitStateBatchChange implements LevitStateChange<void> {
  /// The list of (reactive, change) pairs in this batch.
  final List<(LxReactive, LevitStateChange)> entries;

  /// Unique identifier for this batch within the session.
  final int batchId;

  @override
  final DateTime timestamp;

  /// Creates a composite change from a list of entries.
  LevitStateBatchChange(this.entries, {int? batchId})
      : batchId = batchId ?? ++_batchCounter,
        timestamp = DateTime.now();

  /// Creates a composite change from separate lists (legacy compatibility).
  factory LevitStateBatchChange.fromChanges(List<LevitStateChange> changes) {
    // For backward compatibility when we don't have reactive references
    return LevitStateBatchChange([]);
  }

  /// Convenience getter for just the changes.
  List<LevitStateChange> get changes => entries.map((e) => e.$2).toList();

  /// Convenience getter for just the reactive variables.
  List<LxReactive> get reactiveVariables => entries.map((e) => e.$1).toList();

  /// The number of changes in this batch.
  int get length => entries.length;

  /// Whether this batch is empty.
  bool get isEmpty => entries.isEmpty;

  /// Whether this batch is not empty.
  bool get isNotEmpty => entries.isNotEmpty;

  @override
  Type get valueType => LevitStateBatchChange;

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

class LevitStateMiddleware {
  /// Global middlewares (active wrappers).
  static final List<LevitStateMiddleware> _middlewares = [];

  static bool _hasSetMiddlewares = false;
  static bool get hasSetMiddlewares => _hasSetMiddlewares;

  static bool _hasBatchMiddlewares = false;
  static bool get hasBatchMiddlewares => _hasBatchMiddlewares;

  static bool _hasDisposeMiddlewares = false;
  static bool get hasDisposeMiddlewares => _hasDisposeMiddlewares;

  static bool _hasInitMiddlewares = false;
  static bool get hasInitMiddlewares => _hasInitMiddlewares;

  static bool _hasGraphChangeMiddlewares = false;
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

  /// Adds a middleware.
  static LevitStateMiddleware add(LevitStateMiddleware middleware) {
    _middlewares.add(middleware);
    _updateFlags();
    return middleware;
  }

  static bool remove(LevitStateMiddleware middleware) {
    final result = _middlewares.remove(middleware);
    _updateFlags();
    return result;
  }

  static void clear() {
    _middlewares.clear();
    _updateFlags();
  }

  static bool contains(LevitStateMiddleware middleware) {
    return _middlewares.contains(middleware);
  }

  static bool _bypassMiddleware = false;
  static bool get bypassMiddleware => _bypassMiddleware;

  static void runWithoutMiddleware(void Function() action) {
    final prev = _bypassMiddleware;
    _bypassMiddleware = true;
    try {
      action();
    } finally {
      _bypassMiddleware = prev;
    }
  }

  // =========================================================================
  // Wrapper Hooks (Active - can intercept/modify)
  // =========================================================================

  /// Wraps value changes.
  ///
  /// Returns null if this middleware does not intercept value changes.
  LxOnSet? get onSet => null;

  /// Wraps batch execution.
  ///
  /// Returns null if this middleware does not intercept batch execution.
  LxOnBatch? get onBatch => null;

  /// Wraps disposal execution.
  ///
  /// Returns null if this middleware does not intercept disposal.
  LxOnDispose? get onDispose => null;

  // =========================================================================
  // Passive Hooks (Observation - no interception)
  // =========================================================================

  /// Called when a reactive object is initialized.
  ///
  /// Returns null if this middleware does not observe initialization.
  void Function(LxReactive reactive)? get onInit => null;

  /// Called when a computed reactive's dependencies change.
  ///
  /// Returns null if this middleware does not observe graph changes.
  void Function(LxReactive computed, List<LxReactive> dependencies)?
      get onGraphChange => null;
}

/// Helper typedefs for middleware getters.
typedef LxOnSet = void Function(dynamic value) Function(
  void Function(dynamic value) next,
  LxReactive reactive,
  LevitStateChange<dynamic> change,
);

typedef LxOnBatch = dynamic Function() Function(
  dynamic Function() next,
  LevitStateBatchChange change,
);

typedef LxOnDispose = void Function() Function(
  void Function() next,
  LxReactive reactive,
);

@internal
abstract class LevitStateMiddlewareChain {
  static void Function(T) applyOnSet<T>(
    void Function(T) next,
    LxReactive reactive,
    LevitStateChange<T> change,
  ) {
    if (!LevitStateMiddleware.hasSetMiddlewares) return next;

    // Convert strict typed next to dynamic for middleware chain
    void Function(dynamic) current = (dynamic v) => next(v as T);

    // LIFO wrapping ensures the last added middleware wraps the inner ones.
    for (final mw in LevitStateMiddleware._middlewares.reversed) {
      if (mw.onSet != null) {
        current =
            mw.onSet!(current, reactive, change as LevitStateChange<dynamic>);
      }
    }

    // Convert back to strict typed return
    return (T val) => current(val);
  }

  static dynamic Function() applyOnBatch(
    dynamic Function() next,
    LevitStateBatchChange change,
  ) {
    if (!LevitStateMiddleware.hasBatchMiddlewares) return next;
    var current = next;
    for (final mw in LevitStateMiddleware._middlewares.reversed) {
      if (mw.onBatch != null) {
        current = mw.onBatch!(current, change);
      }
    }
    return current;
  }

  static void Function() applyOnDispose(
    void Function() next,
    LxReactive reactive,
  ) {
    if (!LevitStateMiddleware.hasDisposeMiddlewares) return next;
    var current = next;
    for (final mw in LevitStateMiddleware._middlewares.reversed) {
      if (mw.onDispose != null) {
        current = mw.onDispose!(current, reactive);
      }
    }
    return current;
  }

  // --------------------------------------------------------------------------
  // Passive Hooks
  // --------------------------------------------------------------------------

  static void applyOnInit(LxReactive reactive) {
    if (!LevitStateMiddleware.hasInitMiddlewares) return;
    for (final mw in LevitStateMiddleware._middlewares) {
      mw.onInit?.call(reactive);
    }
  }

  static void applyGraphChange(
    LxReactive computed,
    List<LxReactive> dependencies,
  ) {
    if (!LevitStateMiddleware.hasGraphChangeMiddlewares) return;
    for (final mw in LevitStateMiddleware._middlewares) {
      mw.onGraphChange?.call(computed, dependencies);
    }
  }
}

// ============================================================================
// LevitStateHistoryMiddleware - State History Middleware
// ============================================================================

/// A middleware that records state history for undo/redo functionality.
///
/// This middleware tracks all state changes and provides methods to traverse
/// the history.
///
/// ## Usage
/// ```dart
/// final history = LevitStateHistoryMiddleware();
/// Lx.middlewares.add(history);
///
/// // Later...
/// history.undo();
/// ```
class LevitStateHistoryMiddleware extends LevitStateMiddleware {
  /// Maximum history size for [LevitStateHistoryMiddleware].
  static int maxHistorySize = 100;

  /// Creates a new history middleware.
  LevitStateHistoryMiddleware();

  final List<LevitStateChange> _undoStack = [];
  final List<LevitStateChange> _redoStack = [];

  final _version = LxVal(0);

  // Removed _currentBatch as we now rely on LevitStateBatchChange passed to onBatch
  bool _isRestoring = false;

  /// Returns an unmodifiable list of all recorded changes.
  List<LevitStateChange> get changes {
    _version.value;
    return List.unmodifiable(_undoStack);
  }

  /// Returns an unmodifiable list of re-doable changes.
  List<LevitStateChange> get redoChanges {
    _version.value;
    return List.unmodifiable(_redoStack);
  }

  /// The number of recorded changes in the undo stack.
  int get length {
    _version.value;
    return _undoStack.length;
  }

  /// Whether undo is possible (stack is not empty).
  bool get canUndo {
    _version.value;
    return _undoStack.isNotEmpty;
  }

  /// Whether redo is possible.
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

          if (_batchDepth == 0) {
            _addChange(change);
          }
        };
      };

  int _batchDepth = 0;

  @override
  LxOnBatch? get onBatch => (next, change) {
        return () {
          if (_isRestoring) {
            return next();
          }

          _batchDepth++;
          try {
            return next();
          } finally {
            _batchDepth--;
            if (_batchDepth == 0 && change.isNotEmpty) {
              _addChange(change);
            }
          }
        };
      };

  void _addChange(LevitStateChange change) {
    _undoStack.add(change);

    if (maxHistorySize > 0 && _undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
    LevitStateMiddleware.runWithoutMiddleware(() => _version.value++);
  }

  /// Reverts the last change.
  ///
  /// Returns `true` if undo was successful, `false` if history is empty.
  bool undo() {
    if (_undoStack.isEmpty) return false;

    final change = _undoStack.removeLast();
    _redoStack.add(change);

    _applyRestore(change, isUndo: true);
    LevitStateMiddleware.runWithoutMiddleware(() => _version.value++);
    return true;
  }

  /// Re-applies the last undone change.
  ///
  /// Returns `true` if redo was successful, `false` if redo stack is empty.
  bool redo() {
    if (_redoStack.isEmpty) return false;

    final change = _redoStack.removeLast();
    _undoStack.add(change);

    _applyRestore(change, isUndo: false);
    LevitStateMiddleware.runWithoutMiddleware(() => _version.value++);
    return true;
  }

  void _applyRestore(LevitStateChange change, {required bool isUndo}) {
    _isRestoring = true;
    try {
      if (change is LevitStateBatchChange) {
        final listToProcess = isUndo ? change.changes.reversed : change.changes;
        for (final subChange in listToProcess) {
          _restoreSingle(subChange, isUndo: isUndo);
        }
      } else {
        _restoreSingle(change, isUndo: isUndo);
      }
    } finally {
      _isRestoring = false;
    }
  }

  void _restoreSingle(LevitStateChange change, {required bool isUndo}) {
    final valueToRestore = isUndo ? change.oldValue : change.newValue;

    if (change.restore != null) {
      LevitStateMiddleware.runWithoutMiddleware(() {
        change.restore!(valueToRestore);
      });
      return;
    }

    print(
        '[LevitStateHistoryMiddleware] Warning: No restore mechanism for ${change.valueType}');
  }

  /// Clears the entire history (both undo and redo stacks).
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    LevitStateMiddleware.runWithoutMiddleware(() => _version.value++);
  }

  /// Returns all changes of a specific type.
  List<LevitStateChange> changesOfType(Type type) {
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
