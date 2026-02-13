part of '../levit_monitor.dart';

/// Represents a snapshot of the application state.
class StateSnapshot {
  /// Active Dependency Injection scopes, keyed by scope ID.
  final scopes = <int, ScopeModel>{}.lx;

  /// Active Dependencies, keyed by composite ID "scopeId:key".
  final dependencies = <String, DependencyModel>{}.lx;

  /// Active Reactive variables, keyed by reactive ID.
  final variables = <int, ReactiveModel>{}.lx;

  /// The maximum number of events to keep in the cache.
  final int maxEvents;

  final ListQueue<MonitorEvent> _eventCache;

  /// Returns a snapshot of the cached events.
  List<MonitorEvent> get events => _eventCache.toList();

  StateSnapshot({this.maxEvents = 10000}) : _eventCache = ListQueue(maxEvents);

  Map<String, dynamic> toJson() => {
        'scopes': scopes.values.map((e) => e.toJson()).toList(),
        'dependencies': dependencies.values.map((e) => e.toJson()).toList(),
        'variables': variables.values.map((e) => e.toJson()).toList(),
      };

  /// Applies an incoming event to update the shadow state.
  void applyEvent(MonitorEvent event) {
    _cacheEvent(event);
    if (event is DependencyEvent) {
      _applyDependencyEvent(event);
    } else if (event is ReactiveEvent) {
      _applyReactiveEvent(event);
    } else if (event is ReactiveBatchEvent) {
      _applyBatchEvent(event);
    } else if (event is SnapshotEvent) {
      _restore(event.state);
    }
  }

  void _cacheEvent(MonitorEvent event) {
    if (event is SnapshotEvent) {
      return; // Don't cache snapshots, they are too big
    }
    _eventCache.add(event);
    if (_eventCache.length > maxEvents) {
      _eventCache.removeFirst();
    }
  }

  void _restore(Map<String, dynamic> state) {
    // Clear current state
    scopes.clear();
    dependencies.clear();
    variables.clear();
    _eventCache.clear();

    // Rehydrate Scopes
    if (state['scopes'] != null) {
      for (final s in state['scopes']) {
        final scope = ScopeModel(
            id: s['id'], name: s['name'], parentScopeId: s['parentScopeId']);
        scopes[scope.id] = scope;
      }
    }

    // Rehydrate Dependencies
    if (state['dependencies'] != null) {
      for (final d in state['dependencies']) {
        final dep = DependencyModel(
          scopeId: d['scopeId'],
          key: d['key'],
          isLazy: d['isLazy'],
          isFactory: d['isFactory'],
          isAsync: d['isAsync'],
          status:
              DependencyStatus.values.firstWhere((e) => e.name == d['status']),
          type: d['type'] != null
              ? DependencyType.values.firstWhere((e) => e.name == d['type'])
              : DependencyType.other,
          value: d['value'],
        );
        dependencies['${dep.scopeId}:${dep.key}'] = dep;
      }
    }

    // Rehydrate Variables
    if (state['variables'] != null) {
      for (final v in state['variables']) {
        final reactive = ReactiveModel(
          id: v['id'],
          name: v['name'],
          ownerId: v['ownerId'],
        );
        reactive.value = v['value'];
        reactive.valueType = v['valueType'];
        reactive.isSensitive = v['isSensitive'] ?? false;
        reactive.listenerCount = v['listenerCount'] ?? 0;
        if (v['dependencies'] != null) {
          reactive.dependencies = List<int>.from(v['dependencies']);
        }
        variables[reactive.id] = reactive;
      }
    }
  }

  void _applyDependencyEvent(DependencyEvent event) {
    if (event is ScopeCreateEvent) {
      scopes[event.scopeId] = ScopeModel(
        id: event.scopeId,
        name: event.scopeName,
        parentScopeId: event.parentScopeId,
      );
      return;
    } else if (event is ScopeDisposeEvent) {
      scopes.remove(event.scopeId);
      // Clean up dependencies belonging to this scope
      // Note: LxMap iteration might need .value.entries or similar if safe iteration is needed
      // But typically .removeWhere works on LxMap too.
      // If LxMap doesn't support removeWhere, we iterate keys.
      // Let's assume standard Map methods are going to be proxy or use .value
      // Actually, safely we can collect keys to remove.
      final keysToRemove = dependencies.values
          .where((d) => d.scopeId == event.scopeId)
          .map((d) => '${d.scopeId}:${d.key}')
          .toList();

      for (final key in keysToRemove) {
        dependencies.remove(key);
      }
      return;
    }

    // Ensure scope exists (fallback for legacy/race conditions)
    if (!scopes.containsKey(event.scopeId)) {
      scopes[event.scopeId] =
          ScopeModel(id: event.scopeId, name: event.scopeName);
    }

    final depKey = '${event.scopeId}:${event.key}';

    if (event is DependencyRegisterEvent) {
      dependencies[depKey] = DependencyModel(
        scopeId: event.scopeId,
        key: event.key,
        isLazy: event.info.isLazy,
        isFactory: event.info.isFactory,
        isAsync: event.info.isAsync,
        status: DependencyStatus.registered,
      );
    } else if (event is DependencyDeleteEvent) {
      dependencies.remove(depKey);
    } else if (event is DependencyInstanceCreateEvent) {
      dependencies[depKey]?.status = DependencyStatus.creating;
    } else if (event is DependencyInstanceReadyEvent) {
      final dep = dependencies[depKey];
      if (dep != null) {
        dep.status = DependencyStatus.active;
        dep.value = '<${MonitorEvent._instanceType(event.instance)}>';

        // Detect Dependency Type
        final instance = event.instance;
        if (instance is LevitController) {
          dep.type = DependencyType.controller;
        } else if (instance.runtimeType
            .toString()
            .contains('LevitStoreInstance')) {
          dep.type = DependencyType.store;
        } else {
          dep.type = DependencyType.other;
        }
      }
    }
  }

  void _applyReactiveEvent(ReactiveEvent event) {
    final reactive = variables.putIfAbsent(
      event.reactive.id,
      () => ReactiveModel(
        id: event.reactive.id,
        name: event.reactive.name ?? '?',
        ownerId: event.reactive.ownerId,
        isSensitive: event.reactive.isSensitive,
      ),
    );

    // Update owner info if changed/new
    if (event.reactive.ownerId != null &&
        reactive.ownerId != event.reactive.ownerId) {
      reactive.ownerId = event.reactive.ownerId;
      reactive.parseOwnerId();
    }

    // Update sensitivity
    reactive.isSensitive = event.reactive.isSensitive;

    if (event is ReactiveInitEvent) {
      reactive.value = MonitorEvent._stringify(
        event.reactive.value,
        isSensitive: event.reactive.isSensitive,
      );
      reactive.valueType =
          event.reactive.value?.runtimeType.toString() ?? 'dynamic';
    } else if (event is ReactiveChangeEvent) {
      reactive.value = MonitorEvent._stringify(
        event.change.newValue,
        isSensitive: event.reactive.isSensitive,
      );
      reactive.valueType = event.change.valueType.toString();
    } else if (event is ReactiveDisposeEvent) {
      variables.remove(event.reactive.id);
    } else if (event is ReactiveGraphChangeEvent) {
      reactive.dependencies = event.dependencies.map((d) => d.id).toList();
    } else if (event is ReactiveListenerAddedEvent) {
      reactive.listenerCount++;
    } else if (event is ReactiveListenerRemovedEvent) {
      reactive.listenerCount = (reactive.listenerCount - 1).clamp(0, 9999);
    }
  }

  void _applyBatchEvent(ReactiveBatchEvent event) {
    for (final entry in event.change.entries) {
      final reactiveDef = entry.$1;
      final reactive = variables[reactiveDef.id];
      if (reactive != null) {
        reactive.value = MonitorEvent._stringify(
          entry.$2.newValue,
          isSensitive: reactiveDef.isSensitive,
        );
        reactive.valueType = entry.$2.valueType.toString();
      }
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
  final String name;

  /// The owner identifier associated with the reactive, if any.
  String? ownerId;

  /// Whether the value should be treated as sensitive for display/export.
  bool isSensitive;

  /// The latest stringified value as observed by the monitor.
  dynamic value;

  /// The runtime type name of [value], if known.
  String? valueType;

  // Parsed metadata

  /// The parsed scope identifier from [ownerId], if present.
  int? scopeId;

  /// The parsed owner key from [ownerId], if present.
  String? ownerKey;

  // Graph links (IDs of upstream dependencies)

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
      // Format: scopeId:ownerKey
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
