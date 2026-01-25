part of '../levit_monitor.dart';

/// The foundational middleware that connects the Levit ecosystem to the monitor.
///
/// [LevitMonitorMiddleware] implements the [LevitMiddleware] interface to
/// intercept and capture lifecycle events from across the entire framework.
/// It acts as the bridge between internal state transitions and the external
/// [LevitTransport].
class LevitMonitorMiddleware
    implements LevitReactiveMiddleware, LevitScopeMiddleware {
  bool _enabled = false;

  /// A session identifier generated at initialization to correlate events
  /// within a single application run.
  late final String sessionId;

  /// Whether to capture and include stack trace information for events.
  bool includeStackTrace;

  /// The primary destination for captured events.
  LevitTransport transport;

  /// The local shadow state maintained by the monitor.
  final StateSnapshot _stateSnapshot = StateSnapshot();

  final StreamController<MonitorEvent> _eventStream = StreamController();
  StreamSubscription<MonitorEvent>? _subscription;

  /// Creates a monitor middleware instance.
  LevitMonitorMiddleware({
    LevitTransport? transport,
    this.includeStackTrace = false,
    String? sessionId,
  }) : transport = transport ?? ConsoleTransport() {
    this.sessionId = sessionId ?? _generateSessionId();
  }

  /// Activates the middleware and registers it with the global [Levit] registry.
  void enable() {
    if (!_enabled) {
      Levit.addStateMiddleware(this);
      Levit.addDependencyMiddleware(this);
      _enabled = true;
      _subscription = _eventStream.stream.listen((event) {
        transport.send(event);
      });
      // Listen for reconnection
      transport.onConnect.listen((_) {
        _sendSnapshot();
      });
    }
  }

  void _sendSnapshot() {
    transport.send(SnapshotEvent(
      sessionId: sessionId,
      state: _stateSnapshot.toJson(),
    ));
  }

  /// Deactivates the middleware and stops event processing.
  void disable() {
    if (_enabled) {
      Levit.removeStateMiddleware(this);
      Levit.removeDependencyMiddleware(this);
      _enabled = false;
      _subscription?.cancel();
      _subscription = null;
    }
  }

  /// Swaps the active transport or updates configuration dynamically.
  void updateTransport({
    LevitTransport? transport,
    bool? includeStackTrace,
  }) {
    if (transport != null) {
      this.transport.close();
      this.transport = transport;
    }
    if (includeStackTrace != null) {
      this.includeStackTrace = includeStackTrace;
    }
  }

  static String _generateSessionId() {
    final now = DateTime.now();
    return '${now.millisecondsSinceEpoch.toRadixString(36)}-${now.microsecond.toRadixString(36)}';
  }

  void _addToBuffer(MonitorEvent event) {
    // Filter out internal shadow state events to prevent feedback loops
    if (event is ReactiveEvent) {
      if (identical(event.reactive, _stateSnapshot.variables) ||
          identical(event.reactive, _stateSnapshot.scopes)) {
        return;
      }
    }

    if (!_eventStream.isClosed && LevitMonitor.shouldProcess(event)) {
      // Update local state first
      _stateSnapshot.applyEvent(event);
      _eventStream.add(event);
    }
  }

  // ---------------------------------------------------------------------------
  // Reactive Middleware Implementation
  // ---------------------------------------------------------------------------

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        return (value) {
          next(value);
          _addToBuffer(ReactiveChangeEvent(
            sessionId: sessionId,
            reactive: reactive,
            change: change,
          ));
        };
      };

  @override
  LxOnBatch? get onBatch => (next, change) {
        return () {
          final result = next();

          if (result is Future) {
            return result.whenComplete(() => _logBatch(change));
          } else {
            _logBatch(change);
            return result;
          }
        };
      };

  void _logBatch(LevitReactiveBatch change) {
    _addToBuffer(ReactiveBatchEvent(
      sessionId: sessionId,
      change: change,
    ));
  }

  @override
  void Function(LxReactive reactive)? get onInit => (reactive) {
        _addToBuffer(ReactiveInitEvent(
          sessionId: sessionId,
          reactive: reactive,
        ));
      };

  @override
  LxOnDispose? get onDispose => (next, reactive) {
        return () {
          next();
          _addToBuffer(ReactiveDisposeEvent(
            sessionId: sessionId,
            reactive: reactive,
          ));
        };
      };

  @override
  void Function(LxReactive, List<LxReactive>)? get onGraphChange =>
      (computed, dependencies) {
        _addToBuffer(ReactiveGraphChangeEvent(
          sessionId: sessionId,
          reactive: computed,
          dependencies: dependencies,
        ));
      };

  @override
  void Function(LxReactive reactive, LxListenerContext? context)?
      get startedListening => (reactive, context) {
            _addToBuffer(ReactiveListenerAddedEvent(
              sessionId: sessionId,
              reactive: reactive,
              context: context,
            ));
          };

  @override
  void Function(LxReactive reactive, LxListenerContext? context)?
      get stoppedListening => (reactive, context) {
            _addToBuffer(ReactiveListenerRemovedEvent(
              sessionId: sessionId,
              reactive: reactive,
              context: context,
            ));
          };

  @override
  void Function(Object error, StackTrace? stack, LxReactive? context)?
      get onReactiveError => (error, stack, reactive) {
            _addToBuffer(ReactiveErrorEvent(
              sessionId: sessionId,
              reactive: reactive,
              error: error,
              stack: stack,
            ));
          };

  // ---------------------------------------------------------------------------
  // Scope Observer Implementation
  // ---------------------------------------------------------------------------

  @override
  void onScopeCreate(int scopeId, String scopeName, int? parentScopeId) {
    _addToBuffer(ScopeCreateEvent(
      sessionId: sessionId,
      scopeId: scopeId,
      scopeName: scopeName,
      parentScopeId: parentScopeId,
    ));
  }

  @override
  void onScopeDispose(int scopeId, String scopeName) {
    _addToBuffer(ScopeDisposeEvent(
      sessionId: sessionId,
      scopeId: scopeId,
      scopeName: scopeName,
    ));
  }

  @override
  void onDependencyRegister(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {
    _addToBuffer(DependencyRegisterEvent(
      sessionId: sessionId,
      scopeId: scopeId,
      scopeName: scopeName,
      key: key,
      info: info,
      source: source,
    ));
  }

  @override
  void onDependencyResolve(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {
    _addToBuffer(DependencyResolveEvent(
      sessionId: sessionId,
      scopeId: scopeId,
      scopeName: scopeName,
      key: key,
      info: info,
      source: source,
    ));
  }

  @override
  void onDependencyDelete(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {
    _addToBuffer(DependencyDeleteEvent(
      sessionId: sessionId,
      scopeId: scopeId,
      scopeName: scopeName,
      key: key,
      info: info,
      source: source,
    ));
  }

  @override
  S Function() onDependencyCreate<S>(S Function() builder, LevitScope scope,
      String key, LevitDependency info) {
    return () {
      _addToBuffer(DependencyInstanceCreateEvent(
        sessionId: sessionId,
        scopeId: scope.id,
        scopeName: scope.name,
        key: key,
        info: info,
      ));
      return builder();
    };
  }

  @override
  void Function() onDependencyInit<S>(void Function() onInit, S instance,
      LevitScope scope, String key, LevitDependency info) {
    return () {
      _addToBuffer(DependencyInstanceReadyEvent(
        sessionId: sessionId,
        scopeId: scope.id,
        scopeName: scope.name,
        key: key,
        info: info,
        instance: instance,
      ));
      onInit();
    };
  }

  /// Closes the event stream and releases the underlying transport.
  void close() {
    _eventStream.close();
    _subscription?.cancel();
    transport.close();
  }
}
