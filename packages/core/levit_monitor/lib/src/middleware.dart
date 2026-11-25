part of 'monitor_library.dart';

/// The foundational middleware that connects the Levit ecosystem to the monitor.
///
/// [LevitMonitorMiddleware] implements the necessary middleware interfaces to
/// intercept and capture lifecycle events from across the entire framework.
/// It acts as the bridge between internal state transitions and the external
/// [LevitTransport].
class LevitMonitorMiddleware
    implements
        LevitReactiveMiddleware,
        LevitScopeMiddleware,
        LevitScopeProgressObserver,
        LevitReactiveMetadataObserver {
  bool _enabled = false;

  /// A session identifier generated at initialization to correlate events
  /// within a single application run.
  late final String sessionId;

  /// Whether to capture and include stack trace information for events.
  bool includeStackTrace;

  /// The primary destination for captured events.
  LevitTransport transport;

  final LevitStateSnapshot _stateSnapshot;
  final int maxPendingEvents;
  final ListQueue<LevitFrozenMonitorEvent> _pending = ListQueue();
  final List<AsyncError> _failures = [];
  final List<Future<void>> _subscriptionCleanup = [];
  StreamSubscription<void>? _connectSubscription;
  Future<void>? _pumping;
  Future<void>? _closeFuture;
  Future<void> _transition = Future.value();
  bool _closed = false;
  bool _paused = false;
  int _droppedEvents = 0;
  int get droppedEvents => _droppedEvents + transport.droppedEvents;
  int get pendingEvents => _pending.length;
  List<LevitEventEnvelope> get history => _stateSnapshot.events;
  Map<String, dynamic> get snapshot => LevitEventEnvelope({
    'sessionId': sessionId,
    'seq': 0,
    'type': 'snapshot',
    'category': 'snapshot',
    ..._stateSnapshot.toJson(),
    'droppedEvents': droppedEvents,
  }).data;

  LevitMonitorMiddleware({
    LevitTransport? transport,
    this.includeStackTrace = false,
    String? sessionId,
    this.maxPendingEvents = 1024,
    int historyCapacity = 0,
  }) : transport = transport ?? LevitConsoleTransport(),
       _stateSnapshot = LevitStateSnapshot(maxEvents: historyCapacity) {
    if (maxPendingEvents < 1) {
      throw RangeError.value(maxPendingEvents, 'maxPendingEvents');
    }
    this.sessionId = sessionId ?? _generateSessionId();
  }

  void enable() {
    if (_closed) throw StateError('Monitor is closed.');
    if (_enabled) return;
    Levit.addStateMiddleware(this);
    Levit.addDependencyMiddleware(this);
    _enabled = true;
    _listenForConnect();
  }

  void _listenForConnect() {
    _connectSubscription = transport.onConnect.listen(
      (_) => _sendSnapshot(),
      onError: (Object error, StackTrace stack) => _recordFailure(error, stack),
    );
  }

  void _sendSnapshot() {
    if (_closed) return;
    // A reconnect snapshot replaces remote state. Older queued deltas would
    // corrupt that state if replayed afterwards, so account for and discard them.
    _droppedEvents += _pending.length;
    _pending.clear();
    _enqueue(
      LevitSnapshotEvent(
        sessionId: sessionId,
        state: {
          ..._stateSnapshot.toJson(),
          'droppedEvents': droppedEvents,
          'snapshotKind': 'reconnect',
          'historyComplete': false,
        },
      ).freeze(),
    );
  }

  void disable() {
    if (!_enabled) return;
    _enabled = false;
    Levit.removeStateMiddleware(this);
    Levit.removeDependencyMiddleware(this);
    final subscription = _connectSubscription;
    _connectSubscription = null;
    if (subscription != null) {
      _subscriptionCleanup.add(
        Future<void>.sync(subscription.cancel).catchError(
          (Object error, StackTrace stack) => _recordFailure(error, stack),
        ),
      );
    }
  }

  Future<void> updateTransport({
    LevitTransport? transport,
    bool? includeStackTrace,
  }) {
    final operation = _transition.then((_) async {
      if (_closed) throw StateError('Monitor is closed.');
      if (includeStackTrace != null) this.includeStackTrace = includeStackTrace;
      if (transport == null || identical(transport, this.transport)) return;
      try {
        await _flushQueue();
      } catch (_) {
        /* Failure is retained; still release the old transport. */
      }
      _paused = true;
      try {
        try {
          await _connectSubscription?.cancel();
        } catch (error, stack) {
          _recordFailure(error, stack);
        }
        _connectSubscription = null;
        try {
          await this.transport.close();
        } catch (error, stack) {
          _recordFailure(error, stack);
        }
        this.transport = transport;
        if (_enabled) _listenForConnect();
      } finally {
        _paused = false;
        _sendSnapshot();
      }
      await _flushQueue();
    });
    _transition = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  static final Random _sessionRandom = Random.secure();
  static String _generateSessionId() {
    final buffer = StringBuffer();
    for (var i = 0; i < 4; i++) {
      buffer.write(
        _sessionRandom.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
      );
    }
    return buffer.toString();
  }

  void _recordFailure(Object error, StackTrace stack) {
    if (_failures.length < 32) _failures.add(AsyncError(error, stack));
  }

  void _addToBuffer(LevitMonitorEvent event) {
    if (_closed || !_enabled || !LevitMonitor.shouldProcess(event)) return;
    try {
      final frozen = event.freeze();
      _stateSnapshot.applyEnvelope(frozen.envelope);
      _enqueue(frozen);
    } catch (error, stack) {
      _droppedEvents++;
      _recordFailure(error, stack);
    }
  }

  void _enqueue(LevitFrozenMonitorEvent event) {
    if (_pending.length == maxPendingEvents) {
      _pending.removeFirst();
      _droppedEvents++;
    }
    _pending.add(event);
    _pump();
  }

  void _pump() {
    if (_pumping != null || _paused || _pending.isEmpty) return;
    final complete = Completer<void>();
    _pumping = complete.future;
    scheduleMicrotask(() async {
      try {
        while (!_paused && _pending.isNotEmpty) {
          final event = _pending.removeFirst();
          try {
            final pending = transport.send(event);
            if (pending is Future<void>) await pending;
          } catch (error, stack) {
            _droppedEvents++;
            _recordFailure(error, stack);
          }
        }
      } finally {
        _pumping = null;
        complete.complete();
      }
    });
  }

  /// Awaits queued sends and the transport's own flush. Failures are observable.
  Future<void> flush() async {
    await _transition;
    await _flushQueue();
  }

  Future<void> _flushQueue() async {
    while (!_paused && (_pumping != null || _pending.isNotEmpty)) {
      _pump();
      await _pumping;
    }
    try {
      await transport.flush();
    } catch (error, stack) {
      _recordFailure(error, stack);
    }
    if (_failures.isNotEmpty) throw LevitMonitorException(_failures);
  }

  // ---------------------------------------------------------------------------
  // Reactive Middleware Implementation
  // ---------------------------------------------------------------------------

  @override
  void onReactiveMetadata(LxReactive reactive) {
    if (reactive.isSensitive) {
      final reactiveId = reactive.id.toString();
      _stateSnapshot.scrubSensitiveReactive(reactiveId);
      if (_pending.isNotEmpty) {
        final scrubbed = ListQueue<LevitFrozenMonitorEvent>(_pending.length);
        for (final pending in _pending) {
          final nextEnvelope = _scrubEnvelopeForReactive(
            pending.envelope,
            reactiveId,
          );
          scrubbed.add(
            identical(nextEnvelope, pending.envelope)
                ? pending
                : LevitFrozenMonitorEvent._captured(
                    nextEnvelope,
                    pending.timestamp,
                  ),
          );
        }
        _pending
          ..clear()
          ..addAll(scrubbed);
      }
    }
    _addToBuffer(
      LevitReactiveMetadataEvent(sessionId: sessionId, reactive: reactive),
    );
  }

  @override
  LevitReactiveOnSet? get onSet => (next, reactive, change) {
    return (value) {
      final origin = includeStackTrace ? StackTrace.current : null;
      next(value);
      _addToBuffer(
        LevitReactiveChangeEvent(
          sessionId: sessionId,
          reactive: reactive,
          change: change,
          stackTrace: origin,
        ),
      );
    };
  };

  @override
  LevitReactiveOnBatch? get onBatch => (next, change) {
    return () {
      dynamic result;
      try {
        result = next();
      } catch (_) {
        _logBatch(change);
        rethrow;
      }
      if (change.isAsync && result is Future) {
        return result.whenComplete(() => _logBatch(change));
      }
      _logBatch(change);
      return result;
    };
  };

  void _logBatch(LevitReactiveBatch change) {
    _addToBuffer(LevitReactiveBatchEvent(sessionId: sessionId, change: change));
  }

  @override
  void Function(LxReactive reactive)? get onInit => (reactive) {
    _addToBuffer(
      LevitReactiveInitEvent(sessionId: sessionId, reactive: reactive),
    );
  };

  @override
  LevitReactiveOnDispose? get onDispose => (next, reactive) {
    return () {
      next();
      _addToBuffer(
        LevitReactiveDisposeEvent(sessionId: sessionId, reactive: reactive),
      );
    };
  };

  @override
  void Function(LxReactive, List<LxReactive>)? get onGraphChange =>
      (computed, dependencies) {
        _addToBuffer(
          LevitReactiveGraphChangeEvent(
            sessionId: sessionId,
            reactive: computed,
            dependencies: dependencies,
          ),
        );
      };

  @override
  void Function(LxReactive reactive, LxListenerContext? context)?
  get startedListening => (reactive, context) {
    _addToBuffer(
      LevitReactiveListenerAddedEvent(
        sessionId: sessionId,
        reactive: reactive,
        context: context,
      ),
    );
  };

  @override
  void Function(LxReactive reactive, LxListenerContext? context)?
  get stoppedListening => (reactive, context) {
    _addToBuffer(
      LevitReactiveListenerRemovedEvent(
        sessionId: sessionId,
        reactive: reactive,
        context: context,
      ),
    );
  };

  @override
  void Function(Object error, StackTrace? stack, LxReactive? context)?
  get onReactiveError => (error, stack, reactive) {
    _addToBuffer(
      LevitReactiveErrorEvent(
        sessionId: sessionId,
        reactive: reactive,
        error: error,
        stack: includeStackTrace ? stack : null,
      ),
    );
  };

  // ---------------------------------------------------------------------------
  // Scope Observer Implementation
  // ---------------------------------------------------------------------------

  @override
  void onScopeProgress(LevitScopeDescription description) {
    // Once a closing scope has no remaining work, its terminal disposal event
    // reports completion. Keep progress for live/closing owners with any work,
    // including unexpected terminal records that still contain owned resources.
    if ((description.isClosing || description.isDisposed) &&
        description.pendingInitializations == 0 &&
        description.ownedChildren.isEmpty &&
        description.registrations.isEmpty) {
      return;
    }
    final record = _ScopeProgressEvent.encode(description);
    // Several lifecycle hooks can describe the same state (for example a
    // synchronous initializer followed by registration). Preserve every changed
    // snapshot, without serializing identical derived progress repeatedly.
    final previous = _stateSnapshot.scopes[description.id]?._wireProgress;
    if (_sameProgress(previous, record)) return;
    _addToBuffer(_ScopeProgressEvent(sessionId: sessionId, scope: record));
  }

  static bool _sameProgress(Object? before, Object? after) {
    if (identical(before, after)) return true;
    if (before is List && after is List) {
      if (before.length != after.length) return false;
      for (var i = 0; i < before.length; i++) {
        if (!_sameProgress(before[i], after[i])) return false;
      }
      return true;
    }
    return before == after;
  }

  @override
  void onScopeCreate(int scopeId, String scopeName, int? parentScopeId) {
    _addToBuffer(
      LevitScopeCreateEvent(
        sessionId: sessionId,
        scopeId: scopeId,
        scopeName: scopeName,
        parentScopeId: parentScopeId,
      ),
    );
  }

  @override
  void onScopeDispose(int scopeId, String scopeName) {
    _addToBuffer(
      LevitScopeDisposeEvent(
        sessionId: sessionId,
        scopeId: scopeId,
        scopeName: scopeName,
      ),
    );
  }

  @override
  void onDependencyRegister(
    int scopeId,
    String scopeName,
    String key,
    LevitDependency info, {
    required String source,
    int? parentScopeId,
  }) {
    _addToBuffer(
      LevitDependencyRegisterEvent(
        sessionId: sessionId,
        scopeId: scopeId,
        scopeName: scopeName,
        key: key,
        info: info,
        source: source,
      ),
    );
  }

  @override
  void onDependencyResolve(
    int scopeId,
    String scopeName,
    String key,
    LevitDependency info, {
    required String source,
    int? parentScopeId,
  }) {
    _addToBuffer(
      LevitDependencyResolveEvent(
        sessionId: sessionId,
        scopeId: scopeId,
        scopeName: scopeName,
        key: key,
        info: info,
        source: source,
      ),
    );
  }

  @override
  void onDependencyDelete(
    int scopeId,
    String scopeName,
    String key,
    LevitDependency info, {
    required String source,
    int? parentScopeId,
  }) {
    _addToBuffer(
      LevitDependencyDeleteEvent(
        sessionId: sessionId,
        scopeId: scopeId,
        scopeName: scopeName,
        key: key,
        info: info,
        source: source,
      ),
    );
  }

  @override
  S Function() onDependencyCreate<S>(
    S Function() builder,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) {
    return () {
      _addToBuffer(
        LevitDependencyInstanceCreateEvent(
          sessionId: sessionId,
          scopeId: scope.id,
          scopeName: scope.name,
          key: key,
          info: info,
        ),
      );
      return builder();
    };
  }

  @override
  void Function() onDependencyInit<S>(
    void Function() onInit,
    S instance,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) {
    return () {
      _addToBuffer(
        LevitDependencyInstanceReadyEvent(
          sessionId: sessionId,
          scopeId: scope.id,
          scopeName: scope.name,
          key: key,
          info: info,
          instance: instance,
        ),
      );
      onInit();
    };
  }

  /// Stops event admission, drains queued delivery, then releases transports.
  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    disable();
    _closed = true;
    return _closeFuture = () async {
      await _transition;
      try {
        await flush();
      } catch (_) {
        /* Collected below; still attempt close. */
      }
      for (final cleanup in _subscriptionCleanup) {
        // disable records cancellation failures when adopting this Future.
        await cleanup;
      }
      try {
        await transport.close();
      } catch (error, stack) {
        _recordFailure(error, stack);
      }
      if (_failures.isNotEmpty) throw LevitMonitorException(_failures);
    }();
  }
}
