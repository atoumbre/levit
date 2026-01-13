import 'dart:async';
import 'package:levit_dart/levit_dart.dart';

import '../core/transport.dart';
import '../core/event.dart';
import '../transports/console_transport.dart';
import '../../levit_monitor.dart' show LevitMonitor;

/// The unified Levit middleware for monitoring and DevTools integration.
class MonitorMiddleware extends LevitMiddleware {
  bool _enabled = false;

  /// Session-wide unique identifier for correlating events.
  late final String sessionId;

  /// Whether to include stack traces in the log output (legacy, handled by transport now).
  bool includeStackTrace;

  /// The transport used to send events.
  LevitTransport transport;

  final StreamController<MonitorEvent> _eventStream = StreamController();
  StreamSubscription<MonitorEvent>? _subscription;

  /// Creates a unified Levit monitor middleware.
  MonitorMiddleware({
    LevitTransport? transport,
    this.includeStackTrace = false,
    String? sessionId,
  }) : transport = transport ?? const ConsoleTransport() {
    this.sessionId = sessionId ?? _generateSessionId();
  }

  void enable() {
    if (!_enabled) {
      Levit.addMiddleware(this);
      _enabled = true;
      _subscription = _eventStream.stream.listen((event) {
        transport.send(event);
      });
    }
  }

  void disable() {
    if (_enabled) {
      Levit.removeMiddleware(this);
      _enabled = false;
      _subscription?.cancel();
      _subscription = null;
    }
  }

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
    if (!_eventStream.isClosed && LevitMonitor.shouldProcess(event)) {
      _eventStream.add(event);
    }
  }

  // --- Reactive Middleware Implementation ---

  @override
  void onReactiveRegister(LxReactive reactive, String ownerId) {
    _addToBuffer(ReactiveInitEvent(
      sessionId: sessionId,
      reactive: reactive,
    ));
  }

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        return (value) {
          next(value);
          _addToBuffer(StateChangeEvent(
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

  void _logBatch(LevitStateBatchChange change) {
    _addToBuffer(BatchEvent(
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
        _addToBuffer(GraphChangeEvent(
          sessionId: sessionId,
          reactive: computed,
          dependencies: dependencies,
        ));
      };

  // --- Scope Observer Implementation ---

  @override
  void onRegister(
      int scopeId, String scopeName, String key, LevitBindingEntry info,
      {required String source, int? parentScopeId}) {
    _addToBuffer(DIRegisterEvent(
      sessionId: sessionId,
      scopeId: scopeId,
      scopeName: scopeName,
      key: key,
      info: info,
      source: source,
    ));
  }

  @override
  void onResolve(
      int scopeId, String scopeName, String key, LevitBindingEntry info,
      {required String source, int? parentScopeId}) {
    _addToBuffer(DIResolveEvent(
      sessionId: sessionId,
      scopeId: scopeId,
      scopeName: scopeName,
      key: key,
      info: info,
      source: source,
    ));
  }

  @override
  void onDelete(
      int scopeId, String scopeName, String key, LevitBindingEntry info,
      {required String source, int? parentScopeId}) {
    _addToBuffer(DIDeleteEvent(
      sessionId: sessionId,
      scopeId: scopeId,
      scopeName: scopeName,
      key: key,
      info: info,
      source: source,
    ));
  }

  @override
  S Function() onCreate<S>(S Function() builder, LevitScope scope, String key,
      LevitBindingEntry info) {
    return () {
      _addToBuffer(DIInstanceCreateEvent(
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
      LevitScope scope, String key, LevitBindingEntry info) {
    return () {
      _addToBuffer(DIInstanceInitEvent(
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

  /// Closes the transport.
  void close() {
    _eventStream.close();
    _subscription?.cancel();
    transport.close();
  }
}
