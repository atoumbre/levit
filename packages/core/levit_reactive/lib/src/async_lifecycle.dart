part of 'reactive_library.dart';

/// Cooperative cancellation and completion for a reactive producer.
///
/// {@category SPI}
abstract interface class LxAsyncResource {
  /// Stops admission and requests cancellation without claiming completion.
  void requestCancel();

  /// Waits for all admitted work and its cleanup.
  Future<void> drain();
}

/// Exception signalling that a reactive execution was cooperatively cancelled.
///
/// {@category Reactive State}
final class LxCancelledException implements Exception {
  /// Creates a reactive cancellation exception.
  const LxCancelledException();

  @override
  String toString() => 'Reactive execution was cancelled.';
}

/// Cleanup failures collected after every admitted operation has settled.
///
/// {@category Reactive State}
final class LxCleanupException implements Exception {
  /// Creates an aggregate cleanup exception, flattening nested
  /// [LxCleanupException] instances and deduplicating identical errors.
  LxCleanupException(Iterable<AsyncError> failures)
    : failures = List<AsyncError>.unmodifiable(_flatten(failures));

  static Iterable<AsyncError> _flatten(Iterable<AsyncError> failures) sync* {
    final seen = Set<Object>.identity();
    Iterable<AsyncError> expand(Iterable<AsyncError> items) sync* {
      for (final item in items) {
        if (item.error is LxCleanupException) {
          yield* expand((item.error as LxCleanupException).failures);
        } else if (seen.add(item.error)) {
          yield item;
        }
      }
    }

    yield* expand(failures);
  }

  /// Unmodifiable list of distinct cleanup failures in collection order.
  final List<AsyncError> failures;

  @override
  String toString() => 'LxCleanupException(${failures.length} failures)';
}

/// Cooperative cancellation context for one reactive execution.
///
/// Cancellation does not abort a running [Future] automatically; callbacks
/// check [isCancelled], call [throwIfCancelled], or await [cancelled].
///
/// {@category Reactive State}
final class LxExecutionContext {
  LxExecutionContext._(this._owner) : _parent = current;

  static final Object _zoneKey = Object();
  final Object _owner;
  final LxExecutionContext? _parent;
  final Completer<void> _cancelled = Completer<void>();
  bool _completed = false;

  /// The context of the current worker/computed callback, if any.
  static LxExecutionContext? get current => Zone.current[_zoneKey];

  /// Whether [resource] is executing in the current asynchronous context.
  static bool isExecuting(Object resource) {
    var context = current;
    while (context != null) {
      if (!context._completed && identical(context._owner, resource)) {
        return true;
      }
      context = context._parent;
    }
    return false;
  }

  /// Whether cooperative cancellation has been requested for this execution.
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when cancellation is requested, not when work has finished.
  Future<void> get cancelled => _cancelled.future;

  /// Throws [LxCancelledException] if [isCancelled] is `true`.
  void throwIfCancelled() {
    if (isCancelled) throw const LxCancelledException();
  }

  void _cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  void _complete() {
    _completed = true;
  }

  R _run<R>(R Function() action) =>
      runZoned(action, zoneValues: {_zoneKey: this});
}

/// Tracks completion separately from cancellation; shared by async sources.
mixin _LxAsyncLifecycle<T> on LxBase<T> implements LxAsyncResource {
  final Set<Future<void>> _pendingWork = {};
  final Set<LxExecutionContext> _executionContexts = {};
  final List<AsyncError> _cleanupFailures = [];
  bool _workCancelled = false;
  Future<void>? _asyncCloseFuture;

  LxExecutionContext _newExecution({bool cancelPrevious = false}) {
    if (cancelPrevious) {
      for (final context in _executionContexts) {
        context._cancel();
      }
    }
    final context = LxExecutionContext._(this);
    if (_workCancelled) context._cancel();
    _executionContexts.add(context);
    return context;
  }

  void _trackWork(Future<void> future, [LxExecutionContext? context]) {
    late final Future<void> tracked;
    tracked = future
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            _cleanupFailures.add(AsyncError(error, stack));
          },
        )
        .whenComplete(() {
          _pendingWork.remove(tracked);
          if (context != null) {
            context._complete();
            _executionContexts.remove(context);
          }
        });
    _pendingWork.add(tracked);
  }

  @override
  void requestCancel() {
    _workCancelled = true;
    for (final context in _executionContexts) {
      context._cancel();
    }
  }

  @override
  Future<void> drain() async {
    if (LxExecutionContext.isExecuting(this)) {
      throw StateError(
        'An execution cannot await disposal of its own producer.',
      );
    }
    while (_pendingWork.isNotEmpty) {
      await Future.wait(_pendingWork.toList());
    }
    if (_cleanupFailures.isNotEmpty) {
      throw LxCleanupException(_cleanupFailures);
    }
  }

  @override
  Future<void> close() {
    if (LxExecutionContext.isExecuting(this)) {
      throw StateError(
        'An execution cannot close its own producer; request cancellation instead.',
      );
    }
    if (_asyncCloseFuture != null) return _asyncCloseFuture!;
    requestCancel();
    final baseClose = super.close();
    final failures = <AsyncError>[];
    return _asyncCloseFuture =
        Future.wait([
          for (final operation in [baseClose, drain()])
            operation.catchError((Object error, StackTrace stack) {
              failures.add(AsyncError(error, stack));
            }),
        ]).then((_) {
          if (failures.isNotEmpty) throw LxCleanupException(failures);
        });
  }
}
