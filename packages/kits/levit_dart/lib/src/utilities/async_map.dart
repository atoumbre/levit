part of '../../levit_dart.dart';

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

/// Read-only observation of one retained asynchronous key.
final class LevitAsyncMapEntry<T> implements LxReadable<LxStatus<T>> {
  final LxResource<LxStatus<T>, _AsyncProducer<T>> _resource;
  LevitAsyncMapEntry._(this._resource);
  int _operations = 0;
  Timer? _expiry;
  Future<void>? _refresh;
  Future<T>? _refreshValue;
  bool get isActive => _resource.isActive;
  bool get isClosed => _resource.isClosed;
  bool get isReplacing => _resource.isReplacing;
  @override
  int get id => _resource.id;
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

/// Task-backed keyed data. An existing entry never revalidates simply because
/// a widget reads it. [fetch] applies freshness and [refresh] joins pending work.
final class LevitAsyncMap<K, T>
    implements LevitDisposable, LevitDrainable, LevitExecutionBoundary {
  final FutureOr<T> Function(K, LevitTaskContext) _load;
  final LevitTaskEngine _engine;
  final bool _ownsEngine;
  final DateTime Function() _now;
  final Duration staleTime, gracePeriod;
  final int maxInactiveEntries;
  final LevitRetryPolicy? retryPolicy;
  final TaskCachePolicy<T>? Function(K)? cachePolicy;
  final String? name;
  final String Function(K)? debugKey;
  final _entries = Lx.createOwned(
    () => LxMap<K, LevitAsyncMapEntry<T>>(null, null, true),
  );
  final _inactive = LinkedHashMap<K, LevitAsyncMapEntry<T>>();
  final _retiring = <Future<void>>{};
  final _producers = Set<_AsyncProducer<T>>.identity();
  final _failures = <LevitDisposalFailure>[];
  bool _closing = false, _disposed = false;
  Future<void>? _closingFuture;

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

  bool get isClosing => _closing;
  bool get isDisposed => _disposed;
  int get length => _entries.length;
  Iterable<K> get keys => List<K>.unmodifiable(_entries.keys);
  bool containsKey(K key) => _entries.containsKey(key);
  LevitAsyncMapEntry<T>? peek(K key) => Lx.untracked(() => _entries[key]);
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
      late final LxResource<LxStatus<T>, _AsyncProducer<T>> resource;
      resource = LxResource(
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

  /// Returns the stable observable for this retained lifetime.
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

  /// Join pending work or replace the completed producer and await its result.
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

  Future<bool> invalidate(K key) async {
    _open();
    final item = peek(key);
    if (item == null) return false;
    if (!item.isActive) return evict(key);
    await refresh(key);
    return true;
  }

  Future<void> invalidateAll() async {
    for (final key in keys) {
      await invalidate(key);
    }
  }

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

  @override
  void assertCanDispose() {
    final running = _currentTaskZone?.execution;
    if (running != null &&
        _producers.any((p) => p.execution.executionId == running.executionId)) {
      throw StateError('An async-map task cannot await its own cleanup.');
    }
  }

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

  @override
  Future<void> dispose() => close();
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
