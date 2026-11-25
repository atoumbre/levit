part of '../levit_monitor.dart';

/// Redacted shadow state with optional bounded event retention (off by default).
/// Only immutable JSON envelopes are retained; live application objects are not.
class StateSnapshot {
  final scopes = <int, ScopeModel>{};
  final dependencies = <String, DependencyModel>{};
  final variables = <int, ReactiveModel>{};
  final taskTrees = <String, Map<String, dynamic>>{};
  final int maxEvents;
  final ListQueue<LevitEventEnvelope> _eventCache = ListQueue();
  int droppedHistoryEvents = 0;
  List<LevitEventEnvelope> get events => List.unmodifiable(_eventCache);
  StateSnapshot({this.maxEvents = 0}) {
    if (maxEvents < 0) throw RangeError.value(maxEvents, 'maxEvents');
  }
  Map<String, dynamic> toJson() => {
    'scopes': scopes.values.map((e) => e.toJson()).toList(),
    'dependencies': dependencies.values.map((e) => e.toJson()).toList(),
    'variables': variables.values.map((e) => e.toJson()).toList(),
    'taskTrees': taskTrees,
    'historyComplete': false,
    'historyCapacity': maxEvents,
    'droppedHistoryEvents': droppedHistoryEvents,
  };
  void applyEvent(MonitorEvent event) => applyEnvelope(event.freeze().envelope);

  /// Applies a previously serialized event, also used for inspector replay.
  void applyEnvelope(LevitEventEnvelope envelope) {
    final data = envelope.data;
    if (envelope.type == 'snapshot') {
      _restore(Map<String, dynamic>.from(data['state'] as Map));
      return;
    }
    if (maxEvents > 0) {
      if (_eventCache.length == maxEvents) {
        _eventCache.removeFirst();
        droppedHistoryEvents++;
      }
      _eventCache.add(envelope);
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
        final record = data['scope'] as List;
        final id = record[0] as int;
        final ancestry = record[4] as List;
        final scope = scopes[id] ??= ScopeModel(
          id: id,
          name: record[1] as String,
          parentScopeId: ancestry.isEmpty ? null : ancestry.first[0] as int,
        );
        scope._wireProgress = record;
        scope._progress = null;
      case 'scope_create':
        scopes[scopeId!] = ScopeModel(
          id: scopeId,
          name: data['scopeName'] as String,
          parentScopeId: data['parentScopeId'] as int?,
        );
      case 'scope_dispose':
        scopes.remove(scopeId);
        dependencies.removeWhere((_, value) => value.scopeId == scopeId);
      case 'di_register':
        scopes.putIfAbsent(
          scopeId!,
          () => ScopeModel(id: scopeId, name: data['scopeName'] as String),
        );
        dependencies[depKey] = DependencyModel(
          scopeId: scopeId,
          key: key!,
          isLazy: data['isLazy'] as bool,
          isFactory: data['isFactory'] as bool,
          isAsync: data['isAsync'] as bool,
          status: DependencyStatus.registered,
        );
      case 'di_delete':
        dependencies.remove(depKey);
      case 'di_instance_create':
        dependencies[depKey]?.status = DependencyStatus.creating;
      case 'di_instance_init':
        final dep = dependencies[depKey];
        if (dep != null) {
          dep.status = DependencyStatus.active;
          dep.value = data['instance'] as String?;
          dep.type = switch (data['dependencyType']) {
            'controller' => DependencyType.controller,
            'store' => DependencyType.store,
            _ => DependencyType.other,
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
  }

  static Map<String, dynamic> _decodeScopeProgress(List record) {
    final ancestry = record[4] as List;
    final flags = record[2] as int;
    return {
      'id': record[0] as int,
      'name': record[1] as String,
      'isClosing': flags & 1 != 0,
      'isDisposed': flags & 2 != 0,
      'pendingInitializations': record[3] as int,
      'parentScopeId': ancestry.isEmpty
          ? null
          : (ancestry.first as List)[0] as int,
      'ancestry': [
        for (final parent in ancestry) {'id': parent[0], 'name': parent[1]},
      ],
      'ownedChildren': [
        for (final child in record[5] as List)
          {'id': child[0], 'name': child[1]},
      ],
      'registrations': [
        for (final entry in record[6] as List)
          {
            'key': entry[0] as String,
            'type': entry[1] as String,
            'aliasOf': entry[2] as String?,
            'isFactory': (entry[3] as int) & 1 != 0,
            'isAsync': (entry[3] as int) & 2 != 0,
            'isLazy': (entry[3] as int) & 4 != 0,
            'permanent': (entry[3] as int) & 8 != 0,
            'isInstantiated': (entry[3] as int) & 16 != 0,
            'isClosing': (entry[3] as int) & 32 != 0,
            'pendingInitializations': entry[4] as int,
            'ownedInstances': entry[5] as int,
          },
      ],
    };
  }

  void _applyVariable(Map<String, dynamic> data, String type) {
    final id = int.parse(data['reactiveId'].toString());
    if (type == 'reactive_dispose') {
      variables.remove(id);
      return;
    }
    final model = variables[id] ??= ReactiveModel(
      id: id,
      name: data['name'] as String? ?? '?',
      ownerId: data['ownerId'] as String?,
    );
    if (data['name'] != null) model.name = data['name'] as String;
    if (data.containsKey('ownerId')) {
      model.ownerId = data['ownerId'] as String?;
      model.parseOwnerId();
    }
    model.isSensitive = data['isSensitive'] as bool? ?? model.isSensitive;
    if (type == 'reactive_metadata' && model.isSensitive) {
      model.value = LevitMonitor.obfuscate(model.value);
    }
    if (type == 'reactive_init' || type == 'state_change') {
      model.value = data[type == 'reactive_init' ? 'initialValue' : 'newValue'];
      model.valueType = data['valueType'] as String?;
    } else if (type == 'graph_change') {
      model.dependencies = (data['dependencies'] as List)
          .map((d) => int.parse(d['id'].toString()))
          .toList();
    } else if (type == 'listener_add') {
      model.listenerCount++;
    } else if (type == 'listener_remove') {
      model.listenerCount = (model.listenerCount - 1).clamp(0, 999999);
    }
  }

  void _restore(Map<String, dynamic> state) {
    scopes.clear();
    dependencies.clear();
    variables.clear();
    taskTrees.clear();
    _eventCache.clear();
    for (final entry in (state['taskTrees'] as Map? ?? {}).entries.take(256)) {
      taskTrees[entry.key as String] = Map<String, dynamic>.from(
        entry.value as Map,
      );
    }
    droppedHistoryEvents = state['droppedHistoryEvents'] as int? ?? 0;
    for (final s in state['scopes'] as List? ?? []) {
      final scope = ScopeModel(
        id: s['id'] as int,
        name: s['name'] as String,
        parentScopeId: s['parentScopeId'] as int?,
      );
      scope.progress = Map<String, dynamic>.from(s['progress'] as Map? ?? {});
      scopes[scope.id] = scope;
    }
    for (final d in state['dependencies'] as List? ?? []) {
      final dep = DependencyModel(
        scopeId: d['scopeId'] as int,
        key: d['key'] as String,
        isLazy: d['isLazy'] as bool,
        isFactory: d['isFactory'] as bool,
        isAsync: d['isAsync'] as bool,
        status: DependencyStatus.values.byName(d['status'] as String),
        type: DependencyType.values.byName(d['type'] as String? ?? 'other'),
        value: d['value'] as String?,
      );
      dependencies['${dep.scopeId}:${dep.key}'] = dep;
    }
    for (final v in state['variables'] as List? ?? []) {
      final model = ReactiveModel(
        id: v['id'] as int,
        name: v['name'] as String,
        ownerId: v['ownerId'] as String?,
        isSensitive: v['isSensitive'] as bool? ?? false,
      );
      model.value = v['value'];
      model.valueType = v['valueType'] as String?;
      model.listenerCount = v['listenerCount'] as int? ?? 0;
      model.dependencies = List<int>.from(v['dependencies'] as List? ?? []);
      variables[model.id] = model;
    }
  }
}

/// A serializable representation of a dependency injection scope.
///
/// A [ScopeModel] describes a scope node (including its parent relationship) in
/// a transport-friendly form.
class ScopeModel {
  /// The scope identifier.
  final int id;

  /// The human-readable scope name.
  final String name;

  /// The parent scope identifier, if this scope has a parent.
  final int? parentScopeId;

  /// Initialization and cleanup metadata from the latest progress event.
  /// Compact records expand on observation, preserving the same named fields.
  Map<String, dynamic> get progress =>
      _progress ??= StateSnapshot._decodeScopeProgress(_wireProgress!);
  set progress(Map<String, dynamic> value) {
    _progress = value;
    _wireProgress = null;
  }

  Map<String, dynamic>? _progress = const {};
  List? _wireProgress;

  /// Creates a scope snapshot model.
  ///
  /// [id] is the scope identifier.
  /// [name] is the scope name.
  /// [parentScopeId] is the parent scope identifier, if any.
  ScopeModel({required this.id, required this.name, this.parentScopeId});

  /// Converts this model to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parentScopeId': parentScopeId,
    'progress': progress,
  };
}

/// The lifecycle state of a dependency registration within a scope.
enum DependencyStatus { registered, creating, active }

/// A coarse classification of a resolved dependency instance.
enum DependencyType { controller, store, other }

/// A serializable representation of a dependency registration.
///
/// A [DependencyModel] describes the registration metadata and current instance
/// state as observed by [StateSnapshot].
class DependencyModel {
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
  DependencyStatus status;

  /// The detected instance classification.
  DependencyType type;

  /// A string representation of the instance, if available.
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
  DependencyModel({
    required this.scopeId,
    required this.key,
    required this.isLazy,
    required this.isFactory,
    required this.isAsync,
    required this.status,
    this.type = DependencyType.other,
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
/// A [ReactiveModel] describes a reactive variable, including its owner
/// information, listener count, and dependency graph links.
class ReactiveModel {
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
  ReactiveModel({
    required this.id,
    required this.name,
    this.ownerId,
    this.isSensitive = false,
  }) {
    parseOwnerId();
  }

  /// Parses [ownerId] into [scopeId] and [ownerKey] when possible.
  void parseOwnerId() {
    if (ownerId == null) return;
    if (ownerId!.contains(':')) {
      final parts = ownerId!.split(':');
      // Owner path format is "<scopeId>:<registrationKey>".
      if (parts.length >= 2) {
        scopeId = int.tryParse(parts[0]);
        ownerKey = parts.sublist(1).join(':');
      }
    } else {
      ownerKey = ownerId;
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
