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
      // Let's assume standard Map methods are proxied or use .value
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
        dep.value = event.instance.toString();

        // Detect Dependency Type
        final instance = event.instance;
        if (instance is LevitController) {
          dep.type = DependencyType.controller;
        } else if (instance.runtimeType
            .toString()
            .contains('LevitStateInstance')) {
          dep.type = DependencyType.state;
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
      ),
    );

    // Update owner info if changed/new
    if (event.reactive.ownerId != null &&
        reactive.ownerId != event.reactive.ownerId) {
      reactive.ownerId = event.reactive.ownerId;
      reactive.parseOwnerId();
    }

    if (event is ReactiveInitEvent) {
      reactive.value = event.toJson()['initialValue'];
      reactive.valueType = event.toJson()['valueType'];
    } else if (event is ReactiveChangeEvent) {
      reactive.value = (event.toJson()['newValue']);
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
    final json = event.toJson();
    final entries = json['entries'] as List;

    for (final entry in entries) {
      final id = int.tryParse(entry['reactiveId'].toString());
      if (id != null) {
        final reactive = variables[id];
        if (reactive != null) {
          reactive.value = entry['newValue'];
        }
      }
    }
  }
}

class ScopeModel {
  final int id;
  final String name;
  final int? parentScopeId;

  ScopeModel({required this.id, required this.name, this.parentScopeId});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parentScopeId': parentScopeId,
      };
}

enum DependencyStatus { registered, creating, active }

enum DependencyType { controller, state, other }

class DependencyModel {
  final int scopeId;
  final String key;
  final bool isLazy;
  final bool isFactory;
  final bool isAsync;
  DependencyStatus status;
  DependencyType type;
  String? value;

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

class ReactiveModel {
  final int id;
  final String name;
  String? ownerId;
  dynamic value;
  String? valueType;

  // Parsed metadata
  int? scopeId;
  String? ownerKey;

  // Graph links (IDs of upstream dependencies)
  List<int> dependencies = [];

  int listenerCount = 0;

  ReactiveModel({required this.id, required this.name, this.ownerId}) {
    parseOwnerId();
  }

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'value': value,
        'valueType': valueType,
        'scopeId': scopeId,
        'ownerKey': ownerKey,
        'dependencies': dependencies,
        'listenerCount': listenerCount,
      };
}
