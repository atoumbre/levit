part of 'monitor_library.dart';

/// Redacted shadow state with optional bounded event retention (off by default).
/// Only immutable JSON envelopes are retained; live application objects are not.
///
/// {@category SPI}
class LevitStateSnapshot {
  /// Active scopes keyed by scope ID.
  final scopes = <int, LevitScopeModel>{};

  /// Active dependency registrations keyed by `'<scopeId>:<registrationKey>'`.
  final dependencies = <String, LevitDependencyModel>{};

  /// Active reactive variables keyed by reactive ID.
  final variables = <int, LevitReactiveModel>{};

  /// Live task tree payloads bridged via `levit.tasks` / `tree` custom events
  /// (bounded FIFO at 256 entries; removed when `closed == true`).
  final taskTrees = <String, Map<String, dynamic>>{};

  /// Maximum number of [LevitEventEnvelope]s retained in [events] (`0` disables
  /// history retention).
  final int maxEvents;

  /// Maximum number of reactive variable models retained before evicting oldest
  /// entries.
  final int maxVariables;
  final ListQueue<LevitEventEnvelope> _eventCache = ListQueue();

  /// Total history events evicted due to [maxEvents].
  int droppedHistoryEvents = 0;

  /// Total reactive variable models evicted due to [maxVariables].
  int droppedVariables = 0;

  /// Unmodifiable view of retained [LevitEventEnvelope] history.
  List<LevitEventEnvelope> get events => List.unmodifiable(_eventCache);

  /// Creates an empty shadow-state snapshot.
  ///
  /// Throws a [RangeError] if [maxEvents] < 0 or [maxVariables] < 1.
  LevitStateSnapshot({this.maxEvents = 0, this.maxVariables = 4096}) {
    if (maxEvents < 0) throw RangeError.value(maxEvents, 'maxEvents');
    if (maxVariables < 1) throw RangeError.value(maxVariables, 'maxVariables');
  }

  /// Serializes the current shadow state into a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'scopes': scopes.values.map((e) => e.toJson()).toList(),
    'dependencies': dependencies.values.map((e) => e.toJson()).toList(),
    'variables': variables.values.map((e) => e.toJson()).toList(),
    'taskTrees': taskTrees,
    'historyComplete': false,
    'historyCapacity': maxEvents,
    'droppedHistoryEvents': droppedHistoryEvents,
    'droppedVariables': droppedVariables,
  };

  /// Freezes [event] and applies its envelope to this snapshot.
  void applyEvent(LevitMonitorEvent event) =>
      applyEnvelope(event.freeze().envelope);

  /// Redacts retained history entries for [reactiveId] after sensitivity is enabled.
  void scrubSensitiveReactive(String reactiveId) {
    if (_eventCache.isEmpty) return;
    final updated = ListQueue<LevitEventEnvelope>(_eventCache.length);
    for (final envelope in _eventCache) {
      updated.add(_scrubEnvelopeForReactive(envelope, reactiveId));
    }
    _eventCache
      ..clear()
      ..addAll(updated);
  }

  /// Applies a previously serialized event, also used for inspector replay.
  void applyEnvelope(LevitEventEnvelope envelope) {
    final data = envelope.data;
    if (envelope.type == 'snapshot') {
      final rawState = data['state'];
      if (rawState is! Map) {
        throw const FormatException('Invalid snapshot state payload.');
      }
      _restore(Map<String, dynamic>.from(rawState));
      return;
    }
    final scopeId = data['scopeId'] as int?;
    final key = data['key'] as String?;
    late final depKey = '$scopeId:$key';
    switch (envelope.type) {
      case 'scope_progress':
        if (data['version'] != 1) {
          throw FormatException(
            'Unsupported scope progress version: ${data['version']}',
          );
        }
        final decoded = _decodeScopeProgress(data['scope']);
        final id = decoded['id'] as int;
        final scope =
            scopes[id] ??= LevitScopeModel(
              id: id,
              name: decoded['name'] as String,
              parentScopeId: decoded['parentScopeId'] as int?,
            );
        scope.progress = decoded;
        scope._wireProgress = data['scope'] as List;
      case 'scope_create':
        scopes[scopeId!] = LevitScopeModel(
          id: scopeId,
          name: data['scopeName'] as String,
          parentScopeId: data['parentScopeId'] as int?,
        );
      case 'scope_dispose':
        scopes.remove(scopeId);
        dependencies.removeWhere((_, value) => value.scopeId == scopeId);
        variables.removeWhere((_, value) => value.scopeId == scopeId);
      case 'di_register':
        scopes.putIfAbsent(
          scopeId!,
          () => LevitScopeModel(id: scopeId, name: data['scopeName'] as String),
        );
        dependencies[depKey] = LevitDependencyModel(
          scopeId: scopeId,
          key: key!,
          isLazy: data['isLazy'] as bool,
          isFactory: data['isFactory'] as bool,
          isAsync: data['isAsync'] as bool,
          status: LevitDependencyStatus.registered,
        );
      case 'di_delete':
        dependencies.remove(depKey);
      case 'di_instance_create':
        dependencies[depKey]?.status = LevitDependencyStatus.creating;
      case 'di_instance_init':
        final dep = dependencies[depKey];
        if (dep != null) {
          dep.status = LevitDependencyStatus.active;
          dep.value = data['instance'] as String?;
          dep.type = switch (data['dependencyType']) {
            'controller' => LevitDependencyType.controller,
            'store' => LevitDependencyType.store,
            _ => LevitDependencyType.other,
          };
        }
      case 'custom':
        if (data['namespace'] == 'levit.tasks' &&
            data['name'] == 'tree' &&
            data['attributes'] is Map) {
          final tree = Map<String, dynamic>.from(data['attributes'] as Map);
          final owner = tree['ownerPath'] as String;
          if (tree['closed'] == true) {
            taskTrees.remove(owner);
          } else {
            if (!taskTrees.containsKey(owner) && taskTrees.length >= 256) {
              taskTrees.remove(taskTrees.keys.first);
            }
            taskTrees[owner] = tree;
          }
        }
      case 'batch':
        for (final item in data['entries'] as List) {
          _applyVariable(
            Map<String, dynamic>.from(item as Map),
            'state_change',
          );
        }
      default:
        if (data['reactiveId'] != null) _applyVariable(data, envelope.type);
    }
    if (maxEvents > 0) {
      if (_eventCache.length == maxEvents) {
        _eventCache.removeFirst();
        droppedHistoryEvents++;
      }
      _eventCache.add(envelope);
    }
  }

  static Map<String, dynamic> _decodeScopeProgress(Object? raw) {
    if (raw is! List || raw.length < 7) {
      throw const FormatException('Invalid scope progress record.');
    }
    final id = raw[0];
    final name = raw[1];
    final flags = raw[2];
    final pending = raw[3];
    final ancestry = raw[4];
    final ownedChildren = raw[5];
    final registrations = raw[6];
    if (id is! int ||
        name is! String ||
        flags is! int ||
        pending is! int ||
        ancestry is! List ||
        ownedChildren is! List ||
        registrations is! List) {
      throw const FormatException('Invalid scope progress field types.');
    }
    final parsedAncestry = <Map<String, dynamic>>[];
    for (final parent in ancestry) {
      if (parent is! List ||
          parent.length < 2 ||
          parent[0] is! int ||
          parent[1] is! String) {
        throw const FormatException('Invalid scope progress ancestry entry.');
      }
      parsedAncestry.add({'id': parent[0], 'name': parent[1]});
    }
    final parsedChildren = <Map<String, dynamic>>[];
    for (final child in ownedChildren) {
      if (child is! List ||
          child.length < 2 ||
          child[0] is! int ||
          child[1] is! String) {
        throw const FormatException('Invalid scope progress child entry.');
      }
      parsedChildren.add({'id': child[0], 'name': child[1]});
    }
    final parsedRegistrations = <Map<String, dynamic>>[];
    for (final entry in registrations) {
      if (entry is! List ||
          entry.length < 6 ||
          entry[0] is! String ||
          entry[1] is! String ||
          (entry[2] != null && entry[2] is! String) ||
          entry[3] is! int ||
          entry[4] is! int ||
          entry[5] is! int) {
        throw const FormatException(
          'Invalid scope progress registration entry.',
        );
      }
      final entryFlags = entry[3] as int;
      parsedRegistrations.add({
        'key': entry[0] as String,
        'type': entry[1] as String,
        'aliasOf': entry[2] as String?,
        'isFactory': entryFlags & 1 != 0,
        'isAsync': entryFlags & 2 != 0,
        'isLazy': entryFlags & 4 != 0,
        'permanent': entryFlags & 8 != 0,
        'isInstantiated': entryFlags & 16 != 0,
        'isClosing': entryFlags & 32 != 0,
        'pendingInitializations': entry[4] as int,
        'ownedInstances': entry[5] as int,
      });
    }
    return {
      'id': id,
      'name': name,
      'isClosing': flags & 1 != 0,
      'isDisposed': flags & 2 != 0,
      'pendingInitializations': pending,
      'parentScopeId':
          parsedAncestry.isEmpty ? null : parsedAncestry.first['id'] as int,
      'ancestry': parsedAncestry,
      'ownedChildren': parsedChildren,
      'registrations': parsedRegistrations,
    };
  }

  void _applyVariable(Map<String, dynamic> data, String type) {
    final id = int.parse(data['reactiveId'].toString());
    if (type == 'reactive_dispose') {
      variables.remove(id);
      return;
    }
    var model = variables[id];
    if (model == null) {
      if (variables.length >= maxVariables) {
        variables.remove(variables.keys.first);
        droppedVariables++;
      }
      model =
          variables[id] = LevitReactiveModel(
            id: id,
            name: data['name'] as String? ?? '?',
            ownerId: data['ownerId'] as String?,
          );
    }
    if (data['name'] != null) model.name = data['name'] as String;
    if (data.containsKey('ownerId')) {
      final nextOwnerId = data['ownerId'] as String?;
      if (nextOwnerId != model.ownerId) {
        model.ownerId = nextOwnerId;
        model.parseOwnerId();
      }
    }
    model.isSensitive = data['isSensitive'] as bool? ?? model.isSensitive;
    if (type == 'reactive_metadata' && model.isSensitive) {
      if (model.value != null) {
        model.value = LevitMonitor.obfuscate(model.value);
      }
    }
    if (type == 'reactive_init' || type == 'state_change') {
      final incoming =
          data[type == 'reactive_init' ? 'initialValue' : 'newValue'];
      model.value =
          model.isSensitive && data['isSensitive'] != true && incoming != null
              ? LevitMonitor.obfuscate(incoming)
              : incoming;
      model.valueType = data['valueType'] as String?;
    } else if (type == 'graph_change') {
      model.dependencies =
          (data['dependencies'] as List)
              .map((d) => int.parse(d['id'].toString()))
              .toList();
    } else if (type == 'listener_add') {
      model.listenerCount++;
    } else if (type == 'listener_remove') {
      model.listenerCount = (model.listenerCount - 1).clamp(0, 999999);
    }
  }

  void _restore(Map<String, dynamic> state) {
    final nextTaskTrees = <String, Map<String, dynamic>>{};
    for (final entry in (state['taskTrees'] as Map? ?? {}).entries.take(256)) {
      nextTaskTrees[entry.key as String] = Map<String, dynamic>.from(
        entry.value as Map,
      );
    }
    final nextDroppedHistory = state['droppedHistoryEvents'] as int? ?? 0;
    var nextDroppedVariables = state['droppedVariables'] as int? ?? 0;
    final nextScopes = <int, LevitScopeModel>{};
    for (final s in state['scopes'] as List? ?? []) {
      final scope = LevitScopeModel(
        id: s['id'] as int,
        name: s['name'] as String,
        parentScopeId: s['parentScopeId'] as int?,
      );
      scope.progress = Map<String, dynamic>.from(s['progress'] as Map? ?? {});
      nextScopes[scope.id] = scope;
    }
    final nextDependencies = <String, LevitDependencyModel>{};
    for (final d in state['dependencies'] as List? ?? []) {
      final dep = LevitDependencyModel(
        scopeId: d['scopeId'] as int,
        key: d['key'] as String,
        isLazy: d['isLazy'] as bool,
        isFactory: d['isFactory'] as bool,
        isAsync: d['isAsync'] as bool,
        status: LevitDependencyStatus.values.byName(d['status'] as String),
        type: LevitDependencyType.values.byName(
          d['type'] as String? ?? 'other',
        ),
        value: d['value'] as String?,
      );
      nextDependencies['${dep.scopeId}:${dep.key}'] = dep;
    }
    final nextVariables = <int, LevitReactiveModel>{};
    for (final v in state['variables'] as List? ?? []) {
      final model = LevitReactiveModel(
        id: v['id'] as int,
        name: v['name'] as String,
        ownerId: v['ownerId'] as String?,
        isSensitive: v['isSensitive'] as bool? ?? false,
      );
      model.value = v['value'];
      model.valueType = v['valueType'] as String?;
      model.listenerCount = v['listenerCount'] as int? ?? 0;
      model.dependencies = List<int>.from(v['dependencies'] as List? ?? []);
      if (!nextVariables.containsKey(model.id) &&
          nextVariables.length >= maxVariables) {
        nextVariables.remove(nextVariables.keys.first);
        nextDroppedVariables++;
      }
      nextVariables[model.id] = model;
    }
    scopes
      ..clear()
      ..addAll(nextScopes);
    dependencies
      ..clear()
      ..addAll(nextDependencies);
    variables
      ..clear()
      ..addAll(nextVariables);
    taskTrees
      ..clear()
      ..addAll(nextTaskTrees);
    _eventCache.clear();
    droppedHistoryEvents = nextDroppedHistory;
    droppedVariables = nextDroppedVariables;
  }
}

/// A serializable representation of a dependency injection scope.
///
/// A [LevitScopeModel] describes a scope node (including its parent relationship) in
/// a transport-friendly form.
///
/// {@category SPI}
class LevitScopeModel {
  /// The scope identifier.
  final int id;

  /// The human-readable scope name.
  final String name;

  /// The parent scope identifier, if this scope has a parent.
  final int? parentScopeId;

  /// Initialization and cleanup metadata from the latest progress event.
  Map<String, dynamic> get progress => _progress;

  /// Replaces the scope's progress metadata and invalidates cached wire fields.
  set progress(Map<String, dynamic> value) {
    _progress = value;
    _wireProgress = null;
  }

  Map<String, dynamic> _progress = const {};
  List? _wireProgress;

  /// Creates a scope snapshot model.
  ///
  /// [id] is the scope identifier.
  /// [name] is the scope name.
  /// [parentScopeId] is the parent scope identifier, if any.
  LevitScopeModel({required this.id, required this.name, this.parentScopeId});

  /// Converts this model to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parentScopeId': parentScopeId,
    'progress': progress,
  };
}

/// The lifecycle state of a dependency registration within a scope.
///
/// {@category SPI}
enum LevitDependencyStatus {
  /// Registered lazily and not yet instantiated.
  registered,

  /// Currently running its builder or asynchronous initialization.
  creating,

  /// Instantiated and active in its scope.
  active,
}

/// A coarse classification of a resolved dependency instance.
///
/// {@category SPI}
enum LevitDependencyType {
  /// A `LevitController` instance.
  controller,

  /// A `LevitStore` / `LevitAsyncStore` instance holder.
  store,

  /// Any other service or dependency object.
  other,
}

/// A serializable representation of a dependency registration.
///
/// A [LevitDependencyModel] describes the registration metadata and current instance
/// state as observed by [LevitStateSnapshot].
///
/// {@category SPI}
class LevitDependencyModel {
  /// The owning scope identifier.
  final int scopeId;

  /// The registration key within the scope.
  final String key;

  /// Whether this registration is lazy (created on first lookup).
  final bool isLazy;

  /// Whether this registration is a factory (created on every lookup).
  final bool isFactory;

  /// Whether this registration uses an asynchronous builder.
  final bool isAsync;

  /// The current registration lifecycle status.
  LevitDependencyStatus status;

  /// The detected instance classification.
  LevitDependencyType type;

  /// A runtime-type placeholder for the active instance (formatted as
  /// `'<TypeName>'`), or `null` when not yet instantiated. Never retains or
  /// stringifies application instance data.
  String? value;

  /// Creates a dependency snapshot model.
  ///
  /// [scopeId] is the owning scope identifier.
  /// [key] is the registration key within the scope.
  /// [isLazy] indicates whether the registration is lazy.
  /// [isFactory] indicates whether the registration is a factory.
  /// [isAsync] indicates whether the registration is asynchronous.
  /// [status] is the current lifecycle status.
  /// [type] is the detected classification of the instance.
  /// [value] is a string representation of the instance, if present.
  LevitDependencyModel({
    required this.scopeId,
    required this.key,
    required this.isLazy,
    required this.isFactory,
    required this.isAsync,
    required this.status,
    this.type = LevitDependencyType.other,
    this.value,
  });

  /// Converts this model to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'scopeId': scopeId,
    'key': key,
    'isLazy': isLazy,
    'isFactory': isFactory,
    'isAsync': isAsync,
    'status': status.name,
    'type': type.name,
    'value': value,
  };
}

/// A serializable representation of a reactive object and its metadata.
///
/// A [LevitReactiveModel] describes a reactive variable, including its owner
/// information, listener count, and dependency graph links.
///
/// {@category SPI}
class LevitReactiveModel {
  /// The reactive identifier.
  final int id;

  /// The reactive name, if provided by the producer.
  String name;

  /// The owner identifier associated with the reactive, if any.
  String? ownerId;

  /// Whether the value should be treated as sensitive for display/export.
  bool isSensitive;

  /// The latest stringified value as observed by the monitor.
  dynamic value;

  /// The runtime type name of [value], if known.
  String? valueType;

  // Parsed owner metadata for monitor queries.

  /// The parsed scope identifier from [ownerId], if present.
  int? scopeId;

  /// The parsed owner key from [ownerId], if present.
  String? ownerKey;

  // Upstream reactive IDs in the dependency graph.

  /// The IDs of upstream reactive dependencies for this reactive.
  List<int> dependencies = [];

  /// The number of active listeners currently attached to this reactive.
  int listenerCount = 0;

  /// Creates a reactive snapshot model.
  ///
  /// [id] is the reactive identifier.
  /// [name] is the reactive name.
  /// [ownerId] is the owner identifier, if any.
  /// [isSensitive] indicates whether the reactive value is considered sensitive.
  LevitReactiveModel({
    required this.id,
    required this.name,
    this.ownerId,
    this.isSensitive = false,
  }) {
    parseOwnerId();
  }

  /// Parses [ownerId] into [scopeId] and [ownerKey] when possible.
  void parseOwnerId() {
    final current = ownerId;
    if (current == null) return;
    final sep = current.indexOf(':');
    if (sep >= 0) {
      // Owner path format is "<scopeId>:<registrationKey>".
      scopeId = int.tryParse(current.substring(0, sep));
      ownerKey = current.substring(sep + 1);
    } else {
      ownerKey = current;
    }
  }

  /// Converts this model to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ownerId': ownerId,
    'isSensitive': isSensitive,
    'value': value,
    'valueType': valueType,
    'scopeId': scopeId,
    'ownerKey': ownerKey,
    'dependencies': dependencies,
    'listenerCount': listenerCount,
  };
}

LevitEventEnvelope _scrubEnvelopeForReactive(
  LevitEventEnvelope envelope,
  String reactiveId,
) {
  final data = envelope.data;
  if (envelope.type == 'batch') {
    final entries = data['entries'] as List;
    var changed = false;
    final nextEntries = <Object?>[];
    for (final entry in entries) {
      if (entry is Map && entry['reactiveId']?.toString() == reactiveId) {
        changed = true;
        final copy = Map<String, dynamic>.from(entry);
        copy['isSensitive'] = true;
        if (copy['oldValue'] != null) {
          copy['oldValue'] = LevitMonitor.obfuscate(copy['oldValue']);
        }
        if (copy['newValue'] != null) {
          copy['newValue'] = LevitMonitor.obfuscate(copy['newValue']);
        }
        nextEntries.add(copy);
      } else {
        nextEntries.add(entry);
      }
    }
    if (!changed) return envelope;
    return LevitEventEnvelope(
      Map<String, dynamic>.from(data)..['entries'] = nextEntries,
    );
  }

  if (data['reactiveId']?.toString() != reactiveId) return envelope;
  final copy = Map<String, dynamic>.from(data);
  copy['isSensitive'] = true;
  for (final key in const [
    'initialValue',
    'oldValue',
    'newValue',
    'error',
    'stack',
    'stackTrace',
    'context',
  ]) {
    if (copy[key] != null) {
      copy[key] = LevitMonitor.obfuscate(copy[key]);
    }
  }
  return LevitEventEnvelope(copy);
}
