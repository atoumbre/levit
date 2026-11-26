part of '../kit_library.dart';

/// One task execution owned by a keyed resource.
class _AsyncProducer<T> extends LxFuture<T> {
  final LevitTaskExecution<T> execution;
  final void Function(_AsyncProducer<T>) _released;
  final List<DateTime?> _stamp;
  Future<void>? _queryClose;

  factory _AsyncProducer._(
    LevitTaskExecution<T> execution,
    void Function(_AsyncProducer<T>) released,
    DateTime Function() now,
    LxStatus<T>? previous,
  ) {
    final stamp = <DateTime?>[null];
    return _AsyncProducer._internal(
      execution,
      released,
      stamp,
      execution.result.then((value) {
        stamp[0] = now();
        return value;
      }),
      previous,
    );
  }

  _AsyncProducer._internal(
    this.execution,
    this._released,
    this._stamp,
    Future<T> trackedResult,
    LxStatus<T>? previous,
  ) : super(trackedResult, previous: previous);

  DateTime? get succeededAt => _stamp[0];
  @override
  void requestCancel() {
    execution.cancel();
    super.requestCancel();
  }

  @override
  Future<void> close() {
    // Only the owning map can reach this producer. Its public wait boundaries
    // reject self-joins before starting or joining retirement.
    return _queryClose ??= () async {
      try {
        await super.close();
        final failure = execution._takeCleanupFailure?.call();
        if (failure != null) throw LevitDisposalException.aggregate([failure]);
      } finally {
        _released(this);
      }
    }();
  }
}

final class _AsyncMapFrame<T> {
  final LxStatus<T>? data;
  final bool hasData;
  final bool replacing;
  final AsyncError? failure;
  const _AsyncMapFrame(
    this.data,
    this.hasData, {
    this.replacing = false,
    this.failure,
  });

  LxStatus<T> read() {
    final issue = failure;
    if (issue != null) Error.throwWithStackTrace(issue.error, issue.stackTrace);
    if (!hasData) throw StateError('Resource has no published value.');
    return data as LxStatus<T>;
  }
}

final class _AsyncMapResource<T>
    implements LxReadable<LxStatus<T>>, LxAsyncResource {
  final _AsyncProducer<T> Function() _create;
  final String? name;
  final LxVar<_AsyncMapFrame<T>> _state;
  _AsyncProducer<T>? _current;
  void Function()? _listener;
  bool _started = false;
  bool _closing = false;
  Future<void>? _replacement;
  Future<void>? _cleanup;
  Future<void>? _closingFuture;
  final List<AsyncError> _failures = [];

  _AsyncMapResource(
    this._create, {
    this.name,
    String? ownerId,
    void Function(bool active)? onActivityChanged,
  }) : _state = LxSpi.createOwned(
         () => LxVar(
           _AsyncMapFrame<T>(null, false),
           name: name,
           isSensitive: true,
           onListen: onActivityChanged == null
               ? null
               : () => onActivityChanged(true),
           onCancel: onActivityChanged == null
               ? null
               : () => onActivityChanged(false),
         ),
       ) {
    if (ownerId != null) _state.ownerId = ownerId;
  }

  @override
  int get id => _state.id;

  bool get isClosed => _closing;
  bool get isActive => _state.hasListener;
  bool get isReplacing => _state.value.replacing;
  LxStatus<T>? get lastValue => _state.value.data;
  Object? get refreshError => _state.value.failure?.error;
  StackTrace? get refreshStackTrace => _state.value.failure?.stackTrace;

  void _ensureOpen() {
    if (_closing) throw StateError('Resource is closing.');
  }

  void _start() {
    _ensureOpen();
    if (_started) return;
    _started = true;
    _attach();
  }

  void _attach() {
    try {
      final next = Lx.untracked(() => LxSpi.createOwned(_create));
      next.name ??= name;
      next.ownerId ??= _state.ownerId;
      _current = next;
      void publish() {
        if (_closing || !identical(_current, next)) return;
        final data = Lx.untracked(() => next.value);
        _state.value = _AsyncMapFrame(data, true);
      }

      _listener = publish;
      next.addListener(publish);
      final initial = Lx.untracked(() => next.value);
      _state.value = _AsyncMapFrame(initial, true);
    } catch (error, stack) {
      _publishFailure(error, stack);
      rethrow;
    }
  }

  void _publishFailure(Object error, StackTrace stack) {
    if (!_closing) {
      final previous = Lx.untracked(() => _state.value);
      _state.value = _AsyncMapFrame(
        previous.data,
        previous.hasData,
        failure: AsyncError(error, stack),
      );
    }
  }

  @override
  LxStatus<T> get value {
    try {
      _start();
    } catch (_) {
      _state.value;
      rethrow;
    }
    return _state.value.read();
  }

  _AsyncProducer<T> get producer {
    _start();
    return _current!;
  }

  @override
  void addListener(void Function() listener) {
    _ensureOpen();
    try {
      _start();
    } finally {
      _state.addListener(listener);
    }
  }

  @override
  void removeListener(void Function() listener) =>
      _state.removeListener(listener);

  @override
  Stream<LxStatus<T>> get stream => _state.stream.map((frame) => frame.read());

  _AsyncProducer<T>? _detach() {
    final previous = _current;
    final listener = _listener;
    _current = null;
    _listener = null;
    if (previous != null && listener != null) {
      previous.removeListener(listener);
    }
    return previous;
  }

  Future<void> _release(
    _AsyncProducer<T> previous, {
    bool cancel = true,
  }) async {
    final errors = <AsyncError>[];
    if (cancel) previous.requestCancel();
    try {
      await previous.close();
    } catch (e, s) {
      errors.add(AsyncError(e, s));
    }
    if (errors.isNotEmpty) throw LxCleanupException(errors);
  }

  Future<void> refresh() {
    _ensureOpen();
    if (_replacement case final pending?) return pending;
    final c = Completer<void>();
    _replacement = c.future;
    c.future.ignore();
    final old = _detach();
    final previous = Lx.untracked(() => _state.value);
    _started = true;
    unawaited(() async {
      try {
        if (old != null) {
          final barrier = Completer<void>();
          _cleanup = barrier.future;
          barrier.future.ignore();
          try {
            _state.value = _AsyncMapFrame(
              previous.data,
              previous.hasData,
              replacing: true,
            );
          } finally {
            barrier.complete(_release(old));
          }
        }
        if (_cleanup case final pending?) {
          try {
            await pending;
          } finally {
            _cleanup = null;
          }
        }
        if (_closing) throw const LxCancelledException();
        _attach();
        if (_closing) throw const LxCancelledException();
        c.complete();
      } catch (e, s) {
        _publishFailure(e, s);
        c.completeError(e, s);
      } finally {
        _replacement = null;
      }
    }());
    return c.future;
  }

  @override
  void requestCancel() {
    if (_closing) return;
    _closing = true;
    _current?.requestCancel();
  }

  @override
  Future<void> drain() async {
    final errors = <AsyncError>[];
    for (final operation in [_replacement, _cleanup]) {
      if (operation != null) {
        try {
          await operation;
        } on LxCancelledException {
          // Cancellation is expected once the resource is closing.
        } catch (e, s) {
          errors.add(AsyncError(e, s));
        }
      }
    }
    final current = _current;
    if (current != null) {
      await current.drain();
    }
    if (errors.isNotEmpty) throw LxCleanupException(errors);
  }

  Future<void> close() {
    if (_closingFuture case final pending?) return pending;
    final c = Completer<void>();
    _closingFuture = c.future;
    requestCancel();
    unawaited(() async {
      try {
        await drain();
      } catch (e, s) {
        _failures.add(AsyncError(e, s));
      }
      final current = _detach();
      if (current != null) {
        try {
          await _release(current, cancel: false);
        } catch (e, s) {
          _failures.add(AsyncError(e, s));
        }
      }
      try {
        await _state.close();
      } catch (e, s) {
        _failures.add(AsyncError(e, s));
      }
      if (_failures.isEmpty) {
        c.complete();
      } else {
        c.completeError(LxCleanupException(_failures));
      }
    }());
    return c.future;
  }
}

/// Read-only reactive observation of one retained key in a [LevitAsyncMap].
///
/// Implements [LxReadable] over [LxStatus<T>], so it can be read inside
/// `LxComputed`, `LWatch`, `LBuilder`, or `LStatusBuilder`.
///
/// {@category Tasks & Concurrency}
final class LevitAsyncMapEntry<T> implements LxReadable<LxStatus<T>> {
  final _AsyncMapResource<T> _resource;
  LevitAsyncMapEntry._(this._resource);
  int _operations = 0;
  Timer? _expiry;
  Future<void>? _refresh;
  Future<T>? _refreshValue;

  /// Whether this entry currently has active listeners or observers.
  bool get isActive => _resource.isActive;

  /// Whether this entry has been retired or its owning map is closing.
  bool get isClosed => _resource.isClosed;

  /// Whether this entry is currently replacing its underlying producer.
  bool get isReplacing => _resource.isReplacing;

  @override
  int get id => _resource.id;

  /// The current [LxStatus] for this key.
  ///
  /// Exposes replacement errors as [LxError.fromPrevious] and in-flight
  /// replacements as [LxWaiting.fromPrevious] so UI can keep displaying the
  /// previous value. Throws a [StateError] if [isClosed] is `true`.
  @override
  LxStatus<T> get value {
    if (isClosed) throw StateError('Entry is closed.');
    final prior = _resource.lastValue ?? LxIdle<T>();
    if (_resource.refreshError case final failure?) {
      return LxError<T>.fromPrevious(
        failure,
        _resource.refreshStackTrace,
        prior,
      );
    }
    if (isReplacing) return LxWaiting<T>.fromPrevious(prior);
    return _resource.value;
  }

  @override
  void addListener(void Function() listener) => _resource.addListener(listener);
  @override
  void removeListener(void Function() listener) =>
      _resource.removeListener(listener);

  /// A broadcast [Stream] emitting status transitions for this key.
  ///
  /// Closes immediately if [isClosed] is already `true`.
  @override
  Stream<LxStatus<T>> get stream => Stream.multi((output) {
    if (isClosed) {
      output.closeSync();
      return;
    }
    // Sample the status at notification time, including the drain phase. An
    // asynchronous map of the raw producer stream would lose that transition.
    void publish() {
      if (!isClosed) output.addSync(value);
    }

    addListener(publish);
    final lifetime = _resource.stream.listen(
      (_) {},
      onError: (Object _) {},
      onDone: output.closeSync,
    );
    output.onCancel = () {
      removeListener(publish);
      return lifetime.cancel();
    };
  }, isBroadcast: true);
}

/// Task-backed keyed asynchronous data cache with reactive per-key entries.
///
/// An existing entry never revalidates simply because a widget or observer
/// reads it. Call [fetch] to reuse fresh results or load stale ones, and
/// [refresh] to join pending work or force a reload.
///
/// Own [LevitAsyncMap] in a [LevitController] via `own(...)` or await [close]
/// / [dispose] when done. To pass a custom `LevitTaskEngine` or
/// `LevitTaskCachePolicy`, import `package:levit_dart/tasks.dart` (or
/// `package:levit/tasks.dart` / `package:levit_flutter/tasks.dart`).
///
/// ```dart
/// class UsersController extends LevitController {
///   late final users = own(
///     LevitAsyncMap<String, User>(
///       (id, ctx) => api.fetchUser(id),
///       staleTime: const Duration(minutes: 5),
///       name: 'users',
///     ),
///   );
///
///   LxStatus<User> statusFor(String id) => users[id];
///   Future<User> loadUser(String id) => users.fetch(id);
/// }
/// ```
///
/// {@category Tasks & Concurrency}
final class LevitAsyncMap<K, T>
    implements LevitDisposable, LevitDrainable, LevitExecutionBoundary {
  final FutureOr<T> Function(K, LevitTaskContext) _load;
  final LevitTaskEngine _engine;
  final bool _ownsEngine;
  final DateTime Function() _now;

  /// Duration a successful entry remains fresh for [isFresh] and [fetch].
  final Duration staleTime;

  /// Delay before an unobserved entry is automatically retired.
  final Duration gracePeriod;

  /// Maximum number of unobserved entries retained before evicting the oldest.
  final int maxInactiveEntries;

  /// Optional retry policy applied to each key's load execution.
  final LevitRetryPolicy? retryPolicy;

  /// Optional per-key cache policy factory (see `tasks.dart`).
  final LevitTaskCachePolicy<T>? Function(K)? cachePolicy;

  /// Optional diagnostic label prefix for generated entry resources.
  final String? name;

  /// Optional formatter used with [name] to produce readable diagnostic labels.
  final String Function(K)? debugKey;
  final _entries = LxSpi.createOwned(
    () => LxMap<K, LevitAsyncMapEntry<T>>(isSensitive: true),
  );
  final _inactive = LinkedHashMap<K, LevitAsyncMapEntry<T>>();
  final _retiring = <Future<void>>{};
  final _producers = Set<_AsyncProducer<T>>.identity();
  final _failures = <LevitDisposalFailure>[];
  bool _closing = false, _disposed = false;
  Future<void>? _closingFuture;

  /// Creates a task-backed keyed async map using the given loader function.
  ///
  /// * [engine]: Optional shared task engine (from `tasks.dart`). When omitted,
  ///   this map creates and owns an internal engine (`maxConcurrent: 8`) that
  ///   disposes alongside this map.
  /// * [staleTime]: Freshness window for [fetch]. Defaults to 30 seconds.
  /// * [gracePeriod]: Retention delay after an entry loses all listeners.
  ///   Defaults to 30 seconds.
  /// * [maxInactiveEntries]: Maximum cached unobserved entries (must be >= 1).
  ///   Defaults to `128`.
  /// * [retryPolicy]: Optional [LevitRetryPolicy] for failed loads.
  /// * [cachePolicy]: Optional per-key `LevitTaskCachePolicy` factory.
  /// * [name] / [debugKey]: Optional diagnostic naming hooks.
  /// * [now]: Optional clock override for deterministic testing.
  ///
  /// Throws a [RangeError] if [maxInactiveEntries] < 1 or an [ArgumentError]
  /// if [staleTime] or [gracePeriod] is negative.
  LevitAsyncMap(
    this._load, {
    LevitTaskEngine? engine,
    this.staleTime = const Duration(seconds: 30),
    this.gracePeriod = const Duration(seconds: 30),
    this.maxInactiveEntries = 128,
    this.retryPolicy,
    this.cachePolicy,
    this.name,
    this.debugKey,
    DateTime Function()? now,
  }) : _engine = engine ?? LevitTaskEngine(maxConcurrent: 8),
       _ownsEngine = engine == null,
       _now = now ?? DateTime.now {
    if (maxInactiveEntries < 1)
      throw RangeError.value(maxInactiveEntries, 'maxInactiveEntries');
    if (gracePeriod.isNegative || staleTime.isNegative)
      throw ArgumentError('Durations must be nonnegative.');
  }

  /// Whether disposal of this map has started.
  bool get isClosing => _closing;

  /// Whether disposal of this map has completed.
  bool get isDisposed => _disposed;

  /// The number of currently retained entries (active and inactive).
  int get length => _entries.length;

  /// An unmodifiable snapshot of currently retained keys.
  Iterable<K> get keys => List<K>.unmodifiable(_entries.keys);

  /// Whether [key] currently has a retained entry.
  bool containsKey(K key) => _entries.containsKey(key);

  /// Returns the existing entry for [key] without tracking dependencies or
  /// triggering a load, or `null` if absent.
  LevitAsyncMapEntry<T>? peek(K key) => Lx.untracked(() => _entries[key]);

  /// Acquires [entry] for [key] (starting an initial load if absent) and reads
  /// its reactive [LxStatus].
  LxStatus<T> operator [](K key) => entry(key).value;

  String? _label(K key) {
    if (name == null) return null;
    try {
      return '$name[${debugKey?.call(key) ?? key.hashCode.toUnsigned(32).toRadixString(16)}]';
    } catch (_) {
      return '$name[key]';
    }
  }

  void _open() {
    if (_closing) throw StateError('Async map is closing.');
  }

  LevitAsyncMapEntry<T> _acquire(K key, {bool pin = false}) {
    _open();
    var item = peek(key);
    if (item == null) {
      late final _AsyncMapResource<T> resource;
      resource = _AsyncMapResource(
        () {
          final job = _engine.submit(
            (ctx) => _load(key, ctx),
            group: _engine.rootGroup,
            retryPolicy: retryPolicy,
            cachePolicy: cachePolicy?.call(key),
          );
          final producer = _AsyncProducer<T>._(
            job,
            _producers.remove,
            _now,
            resource.lastValue,
          );
          _producers.add(producer);
          return producer;
        },
        name: _label(key),
        ownerId: _entries.ownerId,
        onActivityChanged: (_) {
          if (item != null) _touch(key, item);
        },
      );
      item = LevitAsyncMapEntry._(resource);
      if (pin) item._operations++;
      _entries[key] = item;
      try {
        Lx.untracked(() => resource.value);
      } catch (_) {
        /* The entry exposes initial construction failure as LxError. */
      }
    } else if (pin) {
      item._operations++;
    }
    _touch(key, item);
    return item;
  }

  /// Returns the stable [LevitAsyncMapEntry] for [key], creating it and
  /// starting its initial load if not yet retained.
  ///
  /// Throws a [StateError] if this map is closing or disposed.
  LevitAsyncMapEntry<T> entry(K key) => _acquire(key);

  void _touch(K key, LevitAsyncMapEntry<T> item) {
    if (_closing || !identical(peek(key), item)) return;
    item._expiry?.cancel();
    item._expiry = null;
    _inactive.remove(key);
    if (!item.isActive && item._operations == 0) {
      _inactive[key] = item;
      item._expiry = Timer(gracePeriod, () {
        if (identical(_inactive[key], item)) _retire(key, item).ignore();
      });
    }
    while (_inactive.length > maxInactiveEntries) {
      final oldest = _inactive.entries.first;
      _retire(oldest.key, oldest.value).ignore();
    }
  }

  /// Whether [key] currently holds a successful result younger than [staleTime].
  bool isFresh(K key) {
    final item = peek(key);
    if (item == null ||
        item.isClosed ||
        item.isReplacing ||
        item.value is! LxSuccess<T>) {
      return false;
    }
    final stamp = item._resource.producer.succeededAt;
    return stamp != null && _now().difference(stamp) < staleTime;
  }

  /// Resolves the value for [key], reusing a fresh cached result or joining an
  /// in-flight refresh when available, and otherwise reloading it.
  ///
  /// Throws a [StateError] if called from inside a loader of this map or when
  /// this map is closing.
  Future<T> fetch(K key) async {
    assertCanDispose();
    final creating = peek(key) == null;
    final item = _acquire(key, pin: true);
    try {
      if (creating && item._resource.refreshError != null) item._resource.value;
      if (item._refreshValue case final pending?) {
        return await pending;
      }
      if (!isFresh(key)) {
        _refreshEntry(key, item);
        return await item._refreshValue!;
      }
      return await item._resource.producer.wait;
    } finally {
      item._operations--;
      _touch(key, item);
    }
  }

  /// Joins any pending refresh for [key] or replaces the completed producer
  /// and awaits its new result.
  ///
  /// Throws a [StateError] if called from inside a loader of this map or when
  /// this map is closing, and throws [LxCancelledException] if closed while
  /// refreshing.
  Future<void> refresh(K key) {
    assertCanDispose();
    final creating = peek(key) == null;
    final item = _acquire(key, pin: true);
    if (item._refresh case final pending?) {
      item._operations--;
      return pending;
    }
    return _refreshEntry(key, item, releasePin: true, first: creating);
  }

  Future<void> _refreshEntry(
    K key,
    LevitAsyncMapEntry<T> item, {
    bool releasePin = false,
    bool first = false,
  }) {
    final done = Completer<void>();
    final resultDone = Completer<T>();
    item._refresh = done.future;
    item._refreshValue = resultDone.future;
    done.future.ignore();
    resultDone.future.ignore();
    unawaited(() async {
      try {
        if (first && item._resource.refreshError != null) item._resource.value;
        if (item._resource.refreshError != null ||
            !item._resource.producer.isWaiting) {
          await item._resource.refresh();
        }
        if (_closing || item.isClosed) throw const LxCancelledException();
        final result = await item._resource.producer.wait;
        resultDone.complete(result);
        done.complete();
      } catch (e, s) {
        resultDone.completeError(e, s);
        done.completeError(e, s);
      } finally {
        item._refresh = null;
        item._refreshValue = null;
        if (releasePin) item._operations--;
        _touch(key, item);
      }
    }());
    return done.future;
  }

  /// Invalidates [key]: refreshes it immediately if actively observed, or
  /// evicts it if inactive.
  ///
  /// Returns `false` if [key] is not currently retained.
  Future<bool> invalidate(K key) async {
    _open();
    final item = peek(key);
    if (item == null) return false;
    if (!item.isActive) return evict(key);
    await refresh(key);
    return true;
  }

  /// Calls [invalidate] for every currently retained key.
  Future<void> invalidateAll() async {
    for (final key in keys) {
      await invalidate(key);
    }
  }

  /// Retires and removes an unobserved entry for [key].
  ///
  /// Returns `false` if [key] is not present. Throws a [StateError] if the
  /// entry currently has active observers (`isActive == true`).
  Future<bool> evict(K key) {
    assertCanDispose();
    _open();
    final item = peek(key);
    if (item == null) return Future.value(false);
    if (item.isActive) throw StateError('Cannot evict an observed entry.');
    return _retire(key, item).then((_) => true);
  }

  Future<void> _retire(K key, LevitAsyncMapEntry<T> item) {
    item._expiry?.cancel();
    _inactive.remove(key);
    final closing = item._resource.close();
    final pending = item._refresh;
    final operation = Future.wait([
      closing,
      if (pending != null)
        pending.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
    ]);
    late final Future<void> tracked;
    tracked = operation
        .then<void>(
          (_) {},
          onError: (Object e, StackTrace s) {
            _failures.add(
              LevitDisposalFailure(resource: item, error: e, stackTrace: s),
            );
          },
        )
        .whenComplete(() => _retiring.remove(tracked));
    _retiring.add(tracked);
    _entries.remove(key);
    return operation.then<void>((_) {});
  }

  /// Throws a [StateError] if called from inside an active loader task owned by
  /// this map.
  @override
  void assertCanDispose() {
    final running = _currentTaskZone?.execution;
    if (running != null &&
        _producers.any((p) => p.execution.executionId == running.executionId)) {
      throw StateError('An async-map task cannot await its own cleanup.');
    }
  }

  /// Stops admissions and cooperatively cancels all active entry producers (and
  /// the internal task engine when owned by this map).
  @override
  void requestCancel() {
    if (_closing) return;
    _closing = true;
    for (final item in Lx.untracked(() => _entries.value.values.toList())) {
      item._expiry?.cancel();
      item._resource.requestCancel();
    }
    if (_ownsEngine) _engine.requestCancel();
  }

  /// Waits for all active producers, refreshes, and background retirements to
  /// finish. Throws [LevitDisposalException] if cleanup fails.
  @override
  Future<void> drain() async {
    assertCanDispose();
    final errors = <LevitDisposalFailure>[];
    for (final item in Lx.untracked(() => _entries.value.values.toList())) {
      try {
        await item._resource.drain();
      } catch (e, s) {
        errors.add(
          LevitDisposalFailure(resource: item, error: e, stackTrace: s),
        );
      }
      final pending = item._refresh;
      if (pending != null)
        await pending.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    }
    while (_retiring.isNotEmpty) {
      await Future.wait(_retiring.toList());
    }
    if (errors.isNotEmpty) throw LevitDisposalException.aggregate(errors);
  }

  /// Alias for [close] implementing [LevitDisposable].
  @override
  Future<void> dispose() => close();

  /// Cancels, drains, and retires every entry, closes the internal entry map,
  /// and disposes the task engine if owned by this map.
  ///
  /// Idempotent; throws [LevitDisposalException] if any cleanup step fails.
  Future<void> close() {
    assertCanDispose();
    if (_closingFuture case final pending?) return pending;
    final done = Completer<void>();
    _closingFuture = done.future;
    requestCancel();
    unawaited(() async {
      Future<void> attempt(
        Object target,
        Future<void> Function() action,
      ) async {
        try {
          await action();
        } catch (e, s) {
          _failures.add(
            LevitDisposalFailure(resource: target, error: e, stackTrace: s),
          );
        }
      }

      await attempt(this, drain);
      for (final key in keys.toList().reversed) {
        final item = peek(key)!;
        // Retirement records its own failures, including background eviction.
        await _retire(
          key,
          item,
        ).then<void>((_) {}, onError: (Object _, StackTrace __) {});
      }
      await attempt(_entries, _entries.close);
      if (_ownsEngine) await attempt(_engine, _engine.dispose);
      _disposed = true;
      if (_failures.isEmpty) {
        done.complete();
      } else {
        done.completeError(LevitDisposalException.aggregate(_failures));
      }
    }());
    return done.future;
  }
}
