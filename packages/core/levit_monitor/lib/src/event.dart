part of 'monitor_library.dart';

/// The base class for all diagnostic events in the Levit ecosystem.
///
/// [LevitMonitorEvent] provides a common schema for reactive state transitions,
/// dependency injection and scope lifecycle events, logs, custom events, and
/// state snapshots so they can be serialized and correlated.
///
/// {@category Middleware & Monitoring}
sealed class LevitMonitorEvent {
  /// A monotonically increasing sequence number across the process lifetime.
  final int seq;

  /// The precise timestamp when the event was captured.
  final DateTime timestamp;

  /// A unique identifier for the current application session.
  final String sessionId;

  /// Internal constructor for monitor events.
  LevitMonitorEvent({
    required this.sessionId,
    DateTime? timestamp,
    int? sequence,
  }) : timestamp = timestamp ?? DateTime.now(),
       seq = sequence ?? _nextSeq++;

  static int _nextSeq = 0;
  late final String _timestampJson = timestamp.toIso8601String();
  Map<String, dynamic>? _captureFields;

  /// Converts the event metadata into a standard JSON-encodable map.
  Map<String, dynamic> toJson() => _metadataJson();

  Map<String, dynamic> _metadataJson() =>
      (_captureFields ?? <String, dynamic>{})
        ..['seq'] = seq
        ..['timestamp'] = _timestampJson
        ..['sessionId'] = sessionId;

  /// Captures redaction and serialization now, before buffering or retaining.
  LevitFrozenMonitorEvent freeze() {
    if (this is LevitFrozenMonitorEvent) return this as LevitFrozenMonitorEvent;
    final envelope = LevitEventEnvelope.capture(
      (fields) {
        final previous = _captureFields;
        _captureFields = fields;
        try {
          return toJson();
        } finally {
          _captureFields = previous;
        }
      },
      category: switch (this) {
        LevitDependencyEvent() => 'di',
        _ScopeProgressEvent() => 'di',
        LevitSnapshotEvent() => 'snapshot',
        LevitLogEvent() => 'log',
        LevitCustomMonitorEvent() => 'custom',
        _ => 'state',
      },
    );
    // Preserve custom toJson overrides while avoiding timestamp parsing for the
    // ordinary capture path. DateTime and the encoded timestamp are immutable.
    return envelope.data['timestamp'] == _timestampJson
        ? LevitFrozenMonitorEvent._captured(envelope, timestamp)
        : LevitFrozenMonitorEvent(envelope);
  }

  /// Safeguard for converting arbitrary objects to string representations.
  static dynamic _stringify(dynamic value, {bool isSensitive = false}) {
    if (value == null) return null;
    if (isSensitive || (value is LxReactive && value.isSensitive)) {
      return LevitMonitor.obfuscate(value);
    }
    try {
      if (value is Map || value is Iterable) {
        return _redactNested(value).toString();
      }
      return value.toString();
    } catch (_) {
      return '<unprintable>';
    }
  }

  static dynamic _redactNested(dynamic value, {int depth = 0}) {
    if (value == null) return null;
    if (value is LxReactive && value.isSensitive) {
      return LevitMonitor.obfuscate(value);
    }
    if (depth >= 16) return value;
    if (value is Map) {
      return value.map(
        (key, nested) => MapEntry(
          key is LxReactive && key.isSensitive
              ? LevitMonitor.obfuscate(key)
              : key,
          _redactNested(nested, depth: depth + 1),
        ),
      );
    }
    if (value is Iterable) {
      return value
          .map((item) => _redactNested(item, depth: depth + 1))
          .toList(growable: false);
    }
    return value;
  }

  /// Safeguard for dependency instance payloads: emit only runtime type.
  static String _instanceType(dynamic instance) =>
      instance == null ? 'null' : instance.runtimeType.toString();
}

// ============================================================================
// Reactive Events
// ============================================================================

/// Base class for events tied to a specific [LxReactive] instance.
///
/// Note: [LevitReactiveBatchEvent] and [LevitReactiveErrorEvent] extend
/// [LevitMonitorEvent] directly rather than [LevitReactiveEvent], because they
/// may span multiple reactives or lack a single reactive target.
///
/// {@category Middleware & Monitoring}
sealed class LevitReactiveEvent extends LevitMonitorEvent {
  /// The reactive object that triggered the event.
  final LxReactive reactive;

  /// Creates a reactive monitor event bound to [reactive].
  LevitReactiveEvent({required super.sessionId, required this.reactive});

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..['reactiveId'] = reactive.id.toString()
    ..['name'] = reactive.name
    ..['ownerId'] = reactive.ownerId
    ..['isSensitive'] = reactive.isSensitive;
}

/// Event triggered when a new reactive variable is instantiated.
///
/// {@category Middleware & Monitoring}
class LevitReactiveInitEvent extends LevitReactiveEvent {
  /// Creates a reactive initialization event.
  LevitReactiveInitEvent({required super.sessionId, required super.reactive});
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'type': 'reactive_init',
    'valueType': reactive.value?.runtimeType.toString() ?? 'dynamic',
    'initialValue': LevitMonitorEvent._stringify(
      reactive.value,
      isSensitive: reactive.isSensitive,
    ),
  };
}

/// Event triggered when a reactive object's lifecycle ends.
///
/// {@category Middleware & Monitoring}
class LevitReactiveDisposeEvent extends LevitReactiveEvent {
  /// Creates a reactive disposal event.
  LevitReactiveDisposeEvent({
    required super.sessionId,
    required super.reactive,
  });
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'type': 'reactive_dispose',
  };
}

/// Event triggered by a single state mutation.
///
/// {@category Middleware & Monitoring}
class LevitReactiveChangeEvent extends LevitReactiveEvent {
  /// The change record intercepted from the middleware.
  final LevitReactiveChange change;

  /// Optional call stack captured at the write boundary for update attribution.
  final StackTrace? stackTrace;

  /// Creates a reactive state-change event.
  LevitReactiveChangeEvent({
    required super.sessionId,
    required super.reactive,
    required this.change,
    this.stackTrace,
  });

  @override
  LevitFrozenMonitorEvent freeze() {
    // External subclasses may customize serialization; retain that contract.
    if (runtimeType != LevitReactiveChangeEvent) return super.freeze();
    return LevitFrozenMonitorEvent._captured(
      LevitEventEnvelope.stateChange(
        sessionId: sessionId,
        seq: seq,
        timestamp: _timestampJson,
        reactiveId: reactive.id.toString(),
        name: reactive.name,
        ownerId: reactive.ownerId,
        isSensitive: reactive.isSensitive,
        oldValue:
            LevitMonitorEvent._stringify(
                  change.oldValue,
                  isSensitive: reactive.isSensitive,
                )
                as String?,
        newValue:
            LevitMonitorEvent._stringify(
                  change.newValue,
                  isSensitive: reactive.isSensitive,
                )
                as String?,
        valueType: change.valueType.toString(),
        stackTrace: stackTrace == null
            ? null
            : LevitMonitorEvent._stringify(
                    stackTrace,
                    isSensitive: reactive.isSensitive,
                  )
                  as String?,
      ),
      timestamp,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson()
      ..['type'] = 'state_change'
      ..['oldValue'] = LevitMonitorEvent._stringify(
        change.oldValue,
        isSensitive: reactive.isSensitive,
      )
      ..['newValue'] = LevitMonitorEvent._stringify(
        change.newValue,
        isSensitive: reactive.isSensitive,
      )
      ..['valueType'] = change.valueType.toString()
      ..['isBatch'] = false;
    if (stackTrace != null) {
      data['stackTrace'] = LevitMonitorEvent._stringify(
        stackTrace,
        isSensitive: reactive.isSensitive,
      );
    }
    return data;
  }
}

/// Event triggered at the completion of a reactive batch.
///
/// {@category Middleware & Monitoring}
class LevitReactiveBatchEvent extends LevitMonitorEvent {
  /// The batch record containing all mutations that occurred within the batch.
  final LevitReactiveBatch change;

  /// Creates a reactive batch completion event.
  LevitReactiveBatchEvent({required super.sessionId, required this.change});

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'type': 'batch',
    'batchId': change.batchId,
    'count': change.length,
    'entries': change.entries
        .map(
          (e) => {
            'reactiveId': e.$1.id.toString(),
            'name': e.$1.name,
            'isSensitive': e.$1.isSensitive,
            'oldValue': LevitMonitorEvent._stringify(
              e.$2.oldValue,
              isSensitive: e.$1.isSensitive,
            ),
            'newValue': LevitMonitorEvent._stringify(
              e.$2.newValue,
              isSensitive: e.$1.isSensitive,
            ),
            'valueType': e.$2.valueType.toString(),
          },
        )
        .toList(),
  };
}

/// Event triggered when a computed value's dependency graph is updated.
///
/// {@category Middleware & Monitoring}
class LevitReactiveGraphChangeEvent extends LevitReactiveEvent {
  /// The current set of dependencies for the reactive object.
  final List<LxReactive> dependencies;

  /// Creates a reactive dependency-graph change event.
  LevitReactiveGraphChangeEvent({
    required super.sessionId,
    required super.reactive,
    required this.dependencies,
  });

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'type': 'graph_change',
    'dependencies': dependencies
        .map((d) => {'id': d.id.toString(), 'name': d.name})
        .toList(),
  };
}

/// Event triggered when a new listener subscribes to a reactive object.
///
/// {@category Middleware & Monitoring}
class LevitReactiveListenerAddedEvent extends LevitReactiveEvent {
  /// Context data about the listener (e.g., Widget label, runtimeType).
  final LxListenerContext? context;

  /// Creates a listener-added event.
  LevitReactiveListenerAddedEvent({
    required super.sessionId,
    required super.reactive,
    this.context,
  });

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'type': 'listener_add',
    'context': reactive.isSensitive
        ? (context == null ? null : LevitMonitor.obfuscate(context!.toJson()))
        : context?.toJson(),
  };
}

/// Event triggered when a listener unsubscribes from a reactive object.
///
/// {@category Middleware & Monitoring}
class LevitReactiveListenerRemovedEvent extends LevitReactiveEvent {
  /// Context data about the listener.
  final LxListenerContext? context;

  /// Creates a listener-removed event.
  LevitReactiveListenerRemovedEvent({
    required super.sessionId,
    required super.reactive,
    this.context,
  });

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'type': 'listener_remove',
    'context': reactive.isSensitive
        ? (context == null ? null : LevitMonitor.obfuscate(context!.toJson()))
        : context?.toJson(),
  };
}

/// Event triggered when an unhandled exception is reported during reactive
/// notification or computation.
///
/// {@category Middleware & Monitoring}
class LevitReactiveErrorEvent extends LevitMonitorEvent {
  /// The reactive object context where the error occurred (optional).
  final LxReactive? reactive;

  /// The error object caught.
  final Object error;

  /// The stack trace associated with the error.
  final StackTrace? stack;

  /// Creates a reactive error event.
  LevitReactiveErrorEvent({
    required super.sessionId,
    this.reactive,
    required this.error,
    this.stack,
  });

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'type': 'reactive_error',
    'reactiveId': reactive?.id.toString(),
    'name': reactive?.name,
    'isSensitive': reactive?.isSensitive ?? false,
    'error': LevitMonitorEvent._stringify(
      error,
      isSensitive: reactive?.isSensitive ?? false,
    ),
    'stack': LevitMonitorEvent._stringify(
      stack,
      isSensitive: reactive?.isSensitive ?? false,
    ),
  };
}

// ============================================================================
// Dependency Injection Events
// ============================================================================

/// Base class for events related to the dependency injection system ([Levit]).
///
/// {@category Middleware & Monitoring}
sealed class LevitDependencyEvent extends LevitMonitorEvent {
  /// The unique identifier of the scope where the event occurred.
  final int scopeId;

  /// The descriptive name of the scope.
  final String scopeName;

  /// The registration key of the dependency.
  final String key;

  /// Metadata about the dependency at the time of the event.
  final LevitDependency info;

  /// Creates a dependency or scope lifecycle event.
  LevitDependencyEvent({
    required super.sessionId,
    required this.scopeId,
    required this.scopeName,
    required this.key,
    required this.info,
  });

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..['scopeId'] = scopeId
    ..['scopeName'] = scopeName
    ..['key'] = key
    ..['isLazy'] = info.isLazy
    ..['isFactory'] = info.isFactory
    ..['isAsync'] = info.isAsync
    ..['permanent'] = info.permanent
    ..['isInstantiated'] = info.isInstantiated;
}

/// Event triggered when a new scope is created.
///
/// Wire metadata describes the scope; dependency-only flags are omitted.
///
/// {@category Middleware & Monitoring}
class LevitScopeCreateEvent extends LevitDependencyEvent {
  /// The parent scope identifier, or `null` for a root scope.
  final int? parentScopeId;

  /// Creates a scope creation event.
  LevitScopeCreateEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required this.parentScopeId,
  }) : super(
         key: '',
         info: LevitDependency(),
       ); // Scope lifecycle events have no dependency payload.

  @override
  Map<String, dynamic> toJson() => _metadataJson()
    ..['scopeId'] = scopeId
    ..['scopeName'] = scopeName
    ..['type'] = 'scope_create'
    ..['parentScopeId'] = parentScopeId;
}

/// Event triggered when a scope is disposed, after all cleanup attempts finish.
///
/// Wire metadata describes the scope; dependency-only flags are omitted.
///
/// {@category Middleware & Monitoring}
class LevitScopeDisposeEvent extends LevitDependencyEvent {
  /// Creates a scope disposal event.
  LevitScopeDisposeEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
  }) : super(
         key: '',
         info: LevitDependency(),
       ); // Scope lifecycle events have no dependency payload.

  @override
  Map<String, dynamic> toJson() => _metadataJson()
    ..['scopeId'] = scopeId
    ..['scopeName'] = scopeName
    ..['type'] = 'scope_dispose';
}

/// Event triggered when a dependency is registered with a scope.
///
/// {@category Middleware & Monitoring}
class LevitDependencyRegisterEvent extends LevitDependencyEvent {
  /// Registration source (for example `'put'`, `'lazyPut'`, `'putFactory'`,
  /// `'lazyPutAsync'`, `'putFactoryAsync'`, or `'bindExisting'`).
  final String source;

  /// Creates a dependency registration event.
  LevitDependencyRegisterEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
    required this.source,
  });

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..['type'] = 'di_register'
    ..['source'] = source;
}

/// Event triggered when a dependency instance creation begins.
///
/// {@category Middleware & Monitoring}
class LevitDependencyInstanceCreateEvent extends LevitDependencyEvent {
  /// Creates a new [LevitDependencyInstanceCreateEvent].
  LevitDependencyInstanceCreateEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
  });

  @override
  Map<String, dynamic> toJson() =>
      super.toJson()..['type'] = 'di_instance_create';
}

/// Event triggered when a dependency instance is fully initialized and ready.
///
/// {@category Middleware & Monitoring}
class LevitDependencyInstanceReadyEvent extends LevitDependencyEvent {
  /// The resulting instance.
  final dynamic instance;

  /// Creates a new [LevitDependencyInstanceReadyEvent].
  LevitDependencyInstanceReadyEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
    required this.instance,
  });

  @override
  Map<String, dynamic> toJson() {
    final type = LevitMonitorEvent._instanceType(instance);
    return super.toJson()
      ..['type'] = 'di_instance_init'
      ..['instance'] = '<$type>'
      ..['instanceType'] = type
      ..['dependencyType'] = instance is LevitController
          ? 'controller'
          : type.contains('LevitStoreInstance')
          ? 'store'
          : 'other';
  }
}

/// Event triggered when a dependency is successfully resolved.
///
/// {@category Middleware & Monitoring}
class LevitDependencyResolveEvent extends LevitDependencyEvent {
  /// Resolution source (for example `'find'`, `'findAsync'`, `'findAlias'`, or
  /// `'findAliasAsync'`).
  final String source;

  /// Creates a dependency resolution event.
  LevitDependencyResolveEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
    required this.source,
  });

  @override
  Map<String, dynamic> toJson() {
    final type = LevitMonitorEvent._instanceType(info.instance);
    return super.toJson()
      ..['type'] = 'di_resolve'
      ..['source'] = source
      ..['instance'] = '<$type>'
      ..['instanceType'] = type;
  }
}

/// Event triggered when a dependency is removed from a scope.
///
/// {@category Middleware & Monitoring}
class LevitDependencyDeleteEvent extends LevitDependencyEvent {
  /// The origin of the deletion (for example `'delete'`, `'deleteAlias'`,
  /// `'reset'`, or `'dispose'`).
  final String source;

  /// Creates a new [LevitDependencyDeleteEvent].
  LevitDependencyDeleteEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
    required this.source,
  });

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..['type'] = 'di_delete'
    ..['source'] = source;
}

// ============================================================================
// Log Events
// ============================================================================

/// Event triggered for custom application logs.
///
/// {@category Middleware & Monitoring}
class LevitLogEvent extends LevitMonitorEvent {
  /// The severity level of the log.
  final LevitLogLevel level;

  /// The primary data or message being logged. Can be a string or a serializable object.
  final Object? data;

  /// Whether log payload and error details must be redacted.
  final bool sensitive;

  /// An optional error associated with the log.
  final Object? error;

  /// An optional stack trace associated with the log.
  final StackTrace? stackTrace;

  /// Creates a structured log event.
  LevitLogEvent({
    required super.sessionId,
    required this.level,
    this.data,
    this.sensitive = false,
    this.error,
    this.stackTrace,
  });

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'type': 'log',
    'level': level.name,
    'isSensitive': sensitive,
    'data': sensitive
        ? (data == null ? null : LevitMonitor.obfuscate(data))
        : _serializeData(data),
    if (error != null)
      'error': LevitMonitorEvent._stringify(error, isSensitive: sensitive),
    if (stackTrace != null)
      'stackTrace': LevitMonitorEvent._stringify(
        stackTrace,
        isSensitive: sensitive,
      ),
  };

  static dynamic _serializeData(Object? data) {
    if (data == null) return null;
    if (data is LxReactive && data.isSensitive) {
      return LevitMonitor.obfuscate(data);
    }
    if (data is num || data is String || data is bool) return data;
    final sanitized = data is Map || data is Iterable
        ? LevitMonitorEvent._redactNested(data)
        : data;
    try {
      // Attempt to encode to check if serializable or if it has `toJson()`
      jsonEncode(sanitized);
      return sanitized;
    } catch (_) {
      try {
        return (sanitized as dynamic).toJson();
      } catch (_) {
        return LevitMonitorEvent._stringify(sanitized);
      }
    }
  }
}

// ============================================================================
// Custom Events
// ============================================================================

// Versioned, self-contained progress records avoid repeating field names for
// every registration at every lifecycle boundary. They are never deltas: a
// receiver can recover full ownership metadata even if earlier events dropped.
final class _ScopeProgressEvent extends LevitMonitorEvent {
  final List<Object?> scope;
  _ScopeProgressEvent({required super.sessionId, required this.scope});

  static List<Object?> encode(LevitScopeDescription description) => [
    description.id,
    description.name,
    (description.isClosing ? 1 : 0) | (description.isDisposed ? 2 : 0),
    description.pendingInitializations,
    [
      for (final parent in description.ancestry) [parent.id, parent.name],
    ],
    [
      for (final child in description.ownedChildren) [child.id, child.name],
    ],
    [
      for (final entry in description.registrations)
        [
          entry.key,
          entry.type,
          entry.aliasOf,
          (entry.isFactory ? 1 : 0) |
              (entry.isAsync ? 2 : 0) |
              (entry.isLazy ? 4 : 0) |
              (entry.permanent ? 8 : 0) |
              (entry.isInstantiated ? 16 : 0) |
              (entry.isClosing ? 32 : 0),
          entry.pendingInitializations,
          entry.ownedInstances,
        ],
    ],
  ];

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..['type'] = 'scope_progress'
    ..['version'] = 1
    ..['scope'] = scope;
}

/// A dependency-neutral structured event supplied by an application or adapter.
///
/// Custom events let optional packages bridge their own event models into the
/// monitor without making `levit_monitor` depend on those packages.
///
/// {@category Middleware & Monitoring}
class LevitCustomMonitorEvent extends LevitMonitorEvent {
  /// Stable namespace owned by the event producer.
  final String namespace;

  /// Stable event name within [namespace].
  final String name;

  /// Severity used by transports that support log levels.
  final LevitLogLevel level;

  /// Low-cardinality, structured event attributes.
  final Map<String, Object?> attributes;

  /// Whether all attributes and error details must be redacted.
  final bool sensitive;

  /// Optional error associated with the event.
  final Object? error;

  /// Optional stack trace associated with [error].
  final StackTrace? stackTrace;

  /// Creates a structured custom event.
  LevitCustomMonitorEvent({
    required super.sessionId,
    required this.namespace,
    required this.name,
    this.level = LevitLogLevel.info,
    Map<String, Object?> attributes = const {},
    this.sensitive = false,
    this.error,
    this.stackTrace,
  }) : attributes = Map.unmodifiable(attributes) {
    if (namespace.trim().isEmpty) {
      throw ArgumentError.value(namespace, 'namespace', 'Must not be empty.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty.');
    }
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson()
      ..['type'] = 'custom'
      ..['namespace'] = namespace
      ..['name'] = name
      ..['level'] = level.name
      ..['isSensitive'] = sensitive
      ..['attributes'] = sensitive
          ? LevitMonitor.obfuscate(attributes)
          : _serializeAttributes(attributes);
    if (error != null) {
      data['error'] = LevitMonitorEvent._stringify(
        error,
        isSensitive: sensitive,
      );
    }
    if (stackTrace != null) {
      data['stackTrace'] = LevitMonitorEvent._stringify(
        stackTrace,
        isSensitive: sensitive,
      );
    }
    return data;
  }

  static Map<String, dynamic> _serializeAttributes(
    Map<String, Object?> attributes,
  ) {
    return attributes.map(
      (key, value) => MapEntry(key, _serializeValue(value)),
    );
  }

  static dynamic _serializeValue(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is LxReactive && value.isSensitive) {
      return LevitMonitor.obfuscate(value);
    }
    if (value is DateTime) return value.toIso8601String();
    if (value is Duration) return value.inMicroseconds;
    if (value is Uri) return value.toString();
    if (value is Map) {
      return value.map(
        (key, nested) => MapEntry(
          LevitMonitorEvent._stringify(key).toString(),
          _serializeValue(nested),
        ),
      );
    }
    if (value is Iterable) {
      return value.map(_serializeValue).toList(growable: false);
    }
    return LevitMonitorEvent._stringify(value);
  }
}

// ============================================================================
// Snapshot Events
// ============================================================================

/// Event containing a full state snapshot for reconnection.
///
/// {@category Middleware & Monitoring}
class LevitSnapshotEvent extends LevitMonitorEvent {
  /// The serialized shadow state payload.
  final Map<String, dynamic> state;

  /// Creates a snapshot event holding [state].
  LevitSnapshotEvent({required super.sessionId, required this.state});

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'type': 'snapshot',
    'state': state,
  };
}

/// The only event form retained by monitor queues and passed to transports.
///
/// {@category Middleware & Monitoring}
final class LevitFrozenMonitorEvent extends LevitMonitorEvent {
  /// The deeply immutable wire envelope backing this frozen event.
  final LevitEventEnvelope envelope;
  // Capture already owns the DateTime. Reparsing its wire representation adds
  // a regexp/date conversion to every event without strengthening immutability.
  LevitFrozenMonitorEvent._captured(this.envelope, DateTime timestamp)
    : super(
        sessionId: envelope.sessionId,
        sequence: envelope.seq,
        timestamp: timestamp,
      );

  /// Creates a frozen monitor event from an existing [envelope] whose
  /// `data['timestamp']` is a valid ISO-8601 string.
  LevitFrozenMonitorEvent(this.envelope)
    : super(
        sessionId: envelope.sessionId,
        sequence: envelope.seq,
        timestamp: DateTime.parse(envelope.data['timestamp'] as String),
      );
  @override
  Map<String, dynamic> toJson() => envelope.data;
}

/// Name, ownership or sensitivity changed without changing the reactive value.
///
/// {@category Middleware & Monitoring}
final class LevitReactiveMetadataEvent extends LevitReactiveEvent {
  /// Creates a reactive metadata-change event.
  LevitReactiveMetadataEvent({
    required super.sessionId,
    required super.reactive,
  });
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'type': 'reactive_metadata',
  };
}
