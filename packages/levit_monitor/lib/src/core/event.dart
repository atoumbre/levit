import 'package:levit_dart/levit_dart.dart';

/// One sealed class for BOTH DI and Reactive events.
sealed class MonitorEvent {
  final int seq;
  final DateTime timestamp;
  final String sessionId;

  MonitorEvent({
    required this.sessionId,
    DateTime? timestamp,
  })  : timestamp = timestamp ?? DateTime.now(),
        seq = _nextSeq++;

  static int _nextSeq = 0;

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'timestamp': timestamp.toIso8601String(),
        'sessionId': sessionId,
      };

  static dynamic _stringify(dynamic value) {
    if (value == null) return null;
    try {
      return value.toString();
    } catch (_) {
      return '<unprintable>';
    }
  }
}

// ============================================================================
// REACTIVE EVENTS (from LevitReactiveMiddleware)
// ============================================================================

sealed class ReactiveEvent extends MonitorEvent {
  final LxReactive reactive;
  ReactiveEvent({required super.sessionId, required this.reactive});

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'reactiveId': reactive.id.toString(),
        'name': reactive.name,
        'ownerId': reactive.ownerId,
      };
}

class ReactiveInitEvent extends ReactiveEvent {
  ReactiveInitEvent({required super.sessionId, required super.reactive});
  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'reactive_init',
        'valueType': reactive.value?.runtimeType.toString() ?? 'dynamic',
        'initialValue': MonitorEvent._stringify(reactive.value),
      };
}

class ReactiveDisposeEvent extends ReactiveEvent {
  ReactiveDisposeEvent({required super.sessionId, required super.reactive});
  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'reactive_dispose',
      };
}

class ReactiveChangeEvent extends ReactiveEvent {
  final LevitReactiveChange change;
  ReactiveChangeEvent({
    required super.sessionId,
    required super.reactive,
    required this.change,
  });
  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'state_change',
        'oldValue': MonitorEvent._stringify(change.oldValue),
        'newValue': MonitorEvent._stringify(change.newValue),
        'valueType': change.valueType.toString(),
        'isBatch': false,
      };
}

class ReactiveBatchEvent extends MonitorEvent {
  final LevitReactiveBatch change;
  ReactiveBatchEvent({required super.sessionId, required this.change});
  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'batch',
        'batchId': change.batchId,
        'count': change.length,
        'entries': change.entries
            .map((e) => {
                  'reactiveId': e.$1.id.toString(),
                  'name': e.$1.name,
                  'oldValue': MonitorEvent._stringify(e.$2.oldValue),
                  'newValue': MonitorEvent._stringify(e.$2.newValue),
                  'valueType': e.$2.valueType.toString(),
                })
            .toList(),
      };
}

class ReactiveGraphChangeEvent extends ReactiveEvent {
  final List<LxReactive> dependencies;
  ReactiveGraphChangeEvent({
    required super.sessionId,
    required super.reactive,
    required this.dependencies,
  });
  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'graph_change',
        'dependencies': dependencies
            .map((d) => {
                  'id': d.id.toString(),
                  'name': d.name,
                })
            .toList(),
      };
}

// ============================================================================
// DI EVENTS (from LevitScopeMiddleware)
// ============================================================================

sealed class DependencyEvent extends MonitorEvent {
  final int scopeId;
  final String scopeName;
  final String key;
  final LevitDependency info;

  DependencyEvent({
    required super.sessionId,
    required this.scopeId,
    required this.scopeName,
    required this.key,
    required this.info,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'scopeId': scopeId,
        'scopeName': scopeName,
        'key': key,
        'isLazy': info.isLazy,
        'isFactory': info.isFactory,
        'isAsync': info.isAsync,
        'permanent': info.permanent,
        'isInstantiated': info.isInstantiated,
      };
}

class DependencyRegisterEvent extends DependencyEvent {
  final String source;
  DependencyRegisterEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
    required this.source,
  });
  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'di_register',
        'source': source,
      };
}

class DependencyResolveEvent extends DependencyEvent {
  final String source;
  DependencyResolveEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
    required this.source,
  });
  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'di_resolve',
        'source': source,
        'instance': MonitorEvent._stringify(info.instance),
      };
}

class DependencyDeleteEvent extends DependencyEvent {
  final String source;
  DependencyDeleteEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
    required this.source,
  });
  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'di_delete',
        'source': source,
      };
}

// Special wrapping events
class DependencyInstanceCreateEvent extends DependencyEvent {
  DependencyInstanceCreateEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
  });
  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'di_instance_create',
      };
}

class DependencyInstanceReadyEvent extends DependencyEvent {
  final dynamic instance;
  DependencyInstanceReadyEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
    required this.instance,
  });
  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'di_instance_init',
        'instance': MonitorEvent._stringify(instance),
      };
}
