part of '../levit_scope.dart';

/// Value-free identity of a scope at the time of a snapshot.
final class LevitScopeIdentity {
  final int id;
  final String name;
  const LevitScopeIdentity(this.id, this.name);
}

/// Immutable registration metadata. Aliases borrow their canonical instance.
final class LevitRegistrationDescription {
  final String key;
  final String type;
  final String? aliasOf;
  final bool isFactory;
  final bool isAsync;
  final bool isLazy;
  final bool permanent;
  final bool isInstantiated;
  final bool isClosing;
  final int pendingInitializations;
  final int ownedInstances;

  const LevitRegistrationDescription({
    required this.key,
    required this.type,
    this.aliasOf,
    this.isFactory = false,
    this.isAsync = false,
    this.isLazy = false,
    this.permanent = false,
    this.isInstantiated = false,
    this.isClosing = false,
    this.pendingInitializations = 0,
    this.ownedInstances = 0,
  });

  bool get ownsInstance => aliasOf == null;
  Map<String, Object?> toJson() => {
    'key': key,
    'type': type,
    'aliasOf': aliasOf,
    'isFactory': isFactory,
    'isAsync': isAsync,
    'isLazy': isLazy,
    'permanent': permanent,
    'isInstantiated': isInstantiated,
    'isClosing': isClosing,
    'pendingInitializations': pendingInitializations,
    'ownedInstances': ownedInstances,
  };
}

/// A point-in-time ownership snapshot; later mutations cannot change this view.
final class LevitScopeDescription {
  final int id;
  final String name;
  final bool isClosing;
  final bool isDisposed;
  final int pendingInitializations;

  /// Nearest ancestor first.
  final List<LevitScopeIdentity> ancestry;
  final List<LevitScopeIdentity> ownedChildren;
  final List<LevitRegistrationDescription> registrations;

  LevitScopeDescription({
    required this.id,
    required this.name,
    required this.isClosing,
    required this.isDisposed,
    required this.pendingInitializations,
    required Iterable<LevitScopeIdentity> ancestry,
    required Iterable<LevitScopeIdentity> ownedChildren,
    required Iterable<LevitRegistrationDescription> registrations,
  }) : ancestry = List.unmodifiable(ancestry),
       ownedChildren = List.unmodifiable(ownedChildren),
       registrations = List.unmodifiable(registrations);

  /// Value-free metadata suitable for local inspection and reconnect snapshots.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'isClosing': isClosing,
    'isDisposed': isDisposed,
    'pendingInitializations': pendingInitializations,
    'parentScopeId': ancestry.isEmpty ? null : ancestry.first.id,
    'ancestry': ancestry
        .map((scope) => {'id': scope.id, 'name': scope.name})
        .toList(),
    'ownedChildren': ownedChildren
        .map((scope) => {'id': scope.id, 'name': scope.name})
        .toList(),
    'registrations': registrations
        .map((registration) => registration.toJson())
        .toList(),
  };
}

/// Optional observer for initialization and closing progress without values.
abstract interface class LevitScopeProgressObserver {
  void onScopeProgress(LevitScopeDescription description);
}
