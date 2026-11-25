part of 'reactive_library.dart';

final class _ResourceFrame<T> {
  final T? data;
  final bool hasData;
  final bool replacing;
  final AsyncError? failure;
  const _ResourceFrame(
    this.data,
    this.hasData, {
    this.replacing = false,
    this.failure,
  });
  T read() {
    final issue = failure;
    if (issue != null) Error.throwWithStackTrace(issue.error, issue.stackTrace);
    if (!hasData) throw StateError('Resource has no published value.');
    return data as T;
  }
}

/// Stable observation of one lazily constructed, exclusively owned producer.
/// Refresh connects a new producer only after cleanup of the old one finishes.
final class LxResource<T, R extends LxReactive<T>>
    implements LxReadable<T>, LxAsyncResource {
  final R Function() _create;
  final String? name;
  final LxVar<_ResourceFrame<T>> _state;
  R? _current;
  R? _retiring;
  void Function()? _listener;
  bool _started = false;
  bool _building = false;
  bool _closing = false;
  bool _disposed = false;
  Future<void>? _replacement;
  Future<void>? _cleanup;
  Future<void>? _closingFuture;
  final List<AsyncError> _failures = [];

  LxResource(
    this._create, {
    this.name,
    String? ownerId,
    void Function(bool active)? onActivityChanged,
  }) : _state = LxSpi.createOwned(
         () => LxVar(
           _ResourceFrame<T>(null, false),
           name: name,
           isSensitive: true,
         ),
       ) {
    if (ownerId != null) _state.ownerId = ownerId;
    if (onActivityChanged != null) {
      _state._addActivityObserver(onActivityChanged);
    }
  }

  @override
  int get id => _state.id;
  bool get isClosed => _closing;
  bool get isDisposed => _disposed;
  bool get isActive => _state.hasListener;
  bool get isReplacing => _state.value.replacing;
  bool get hasLastValue => _state.value.hasData;
  T? get lastValue => _state.value.data;
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
    R? created;
    _building = true;
    try {
      final R next = Lx.untracked(() => LxSpi.createOwned(_create));
      created = next;
      next.name ??= name;
      next.ownerId ??= _state.ownerId;
      _current = next;
      void publish() {
        if (_closing || !identical(_current, next)) return;
        try {
          final data = Lx.untracked(() => next.value);
          _state.value = _ResourceFrame(data, true);
        } catch (error, stack) {
          _publishFailure(error, stack);
        }
      }

      _listener = publish;
      next.addListener(publish);
      final initial = Lx.untracked(() => next.value);
      _building = false;
      _state.value = _ResourceFrame(initial, true);
    } catch (error, stack) {
      if (created != null) {
        _detach();
        final retiring = _release(created);
        _cleanup = retiring;
        retiring.ignore();
      }
      _publishFailure(error, stack);
      rethrow;
    } finally {
      _building = false;
    }
  }

  void _publishFailure(Object error, StackTrace stack) {
    if (!_closing) {
      final previous = _state._value;
      _state.value = _ResourceFrame(
        previous.data,
        previous.hasData,
        failure: AsyncError(error, stack),
      );
    }
  }

  @override
  T get value {
    try {
      _start();
    } catch (_) {
      _state.value;
      rethrow;
    }
    return _state.value.read();
  }

  /// Tracked access for domain operations. Unavailable during replacement.
  R get producer {
    _start();
    final frame = _state.value;
    final current = _current;
    if (frame.replacing || current == null) {
      throw StateError('Producer is unavailable.');
    }
    return current;
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
  Stream<T> get stream => Stream.multi((output) {
    if (_closing) {
      output.closeSync();
      return;
    }
    try {
      _start();
    } catch (error, stack) {
      output.addErrorSync(error, stack);
    }
    final subscription = _state.stream
        .map((frame) => frame.read())
        .listen(
          output.addSync,
          onError: output.addErrorSync,
          onDone: output.closeSync,
        );
    output.onCancel = subscription.cancel;
  }, isBroadcast: true);

  /// Reject a wait from the producer that would need to finish that wait.
  void assertCanClose() {
    if (_building ||
        (_current != null && LxExecutionContext.isExecuting(_current!)) ||
        (_retiring != null && LxExecutionContext.isExecuting(_retiring!))) {
      throw StateError(
        'A producer cannot await its own replacement or cleanup.',
      );
    }
  }

  R? _detach() {
    final previous = _current;
    final listener = _listener;
    _current = null;
    _listener = null;
    if (previous != null && listener != null) {
      try {
        previous.removeListener(listener);
      } catch (error, stack) {
        _failures.add(AsyncError(error, stack));
      }
    }
    return previous;
  }

  Future<void> _release(R previous, {bool cancel = true}) async {
    _retiring = previous;
    final errors = <AsyncError>[];
    try {
      if (cancel && previous is LxAsyncResource) {
        try {
          (previous as LxAsyncResource).requestCancel();
        } catch (e, s) {
          errors.add(AsyncError(e, s));
        }
      }
      try {
        await previous.close();
      } catch (e, s) {
        errors.add(AsyncError(e, s));
      }
    } finally {
      _retiring = null;
    }
    if (errors.isNotEmpty) throw LxCleanupException(errors);
  }

  /// Complete after the replacement has attached and supplied a readable value.
  Future<void> refresh() {
    _ensureOpen();
    assertCanClose();
    if (_replacement case final pending?) return pending;
    final c = Completer<void>();
    _replacement = c.future;
    c.future.ignore();
    final old = _detach();
    final previous = _state._value;
    _started = true;
    unawaited(() async {
      try {
        if (old != null) {
          _retiring = old;
          // Reserve cleanup before any external observer can reenter.
          final barrier = Completer<void>();
          _cleanup = barrier.future;
          barrier.future.ignore();
          try {
            _state.value = _ResourceFrame(
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
        Object failure = e;
        if (_cleanup case final failedAttachment?) {
          try {
            await failedAttachment;
          } catch (other, stack) {
            failure = LxCleanupException([
              AsyncError(e, s),
              AsyncError(other, stack),
            ]);
          } finally {
            _cleanup = null;
          }
        }
        _publishFailure(failure, s);
        c.completeError(failure, s);
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
    final current = _current;
    if (current is LxAsyncResource) {
      try {
        (current as LxAsyncResource).requestCancel();
      } catch (e, s) {
        _failures.add(AsyncError(e, s));
      }
    }
  }

  @override
  Future<void> drain() async {
    assertCanClose();
    final errors = <AsyncError>[];
    for (final operation in [_replacement, _cleanup]) {
      if (operation != null) {
        try {
          await operation;
        } on LxCancelledException {
          if (!_closing) rethrow;
        } catch (e, s) {
          errors.add(AsyncError(e, s));
        }
      }
    }
    final current = _current;
    if (current is LxAsyncResource) {
      try {
        await (current as LxAsyncResource).drain();
      } catch (e, s) {
        errors.add(AsyncError(e, s));
      }
    }
    if (errors.isNotEmpty) throw LxCleanupException(errors);
  }

  Future<void> close() {
    assertCanClose();
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
      _disposed = true;
      if (_failures.isEmpty) {
        c.complete();
      } else {
        c.completeError(LxCleanupException(_failures));
      }
    }());
    return c.future;
  }
}
