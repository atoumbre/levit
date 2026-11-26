part of 'scope_library.dart';

/// Value-free identity of a [LevitScope] captured in a snapshot.
///
/// {@category Scopes & DI}
final class LevitScopeIdentity {
  /// Unique runtime scope identifier.
  final int id;

  /// Diagnostic scope name.
  final String name;

  /// Creates a scope identity record.
  const LevitScopeIdentity(this.id, this.name);
}

/// Immutable registration metadata captured by [LevitScope.describe].
///
/// Aliases borrow their canonical instance ([ownsInstance] is `false`).
///
/// {@category Scopes & DI}
final class LevitRegistrationDescription {
  /// Opaque diagnostic key (formatted with `#default` or `#tagN` suffixes).
  final String key;

  /// Runtime type name of the registered dependency.
  final String type;

  /// Canonical registration key when this entry is an alias, or `null` for an
  /// owning registration.
  final String? aliasOf;

  /// Whether a new instance is created on every lookup.
  final bool isFactory;

  /// Whether this registration uses an asynchronous builder.
  final bool isAsync;

  /// Whether instantiation is deferred until first lookup.
  final bool isLazy;

  /// Whether this registration survives non-forced [LevitScope.reset] calls.
  final bool permanent;

  /// Whether a singleton instance is currently instantiated.
  final bool isInstantiated;

  /// Whether this registration is currently retiring/deleting.
  final bool isClosing;

  /// Number of in-flight asynchronous initializations for this registration.
  final int pendingInitializations;

  /// Number of live instances owned by this registration (singleton or active
  /// disposable factory instances).
  final int ownedInstances;

  /// Creates an immutable registration description.
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

  /// Whether this registration owns its instance (`aliasOf == null`).
  bool get ownsInstance => aliasOf == null;

  /// Serializes this registration metadata to a JSON-compatible map.
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

/// A point-in-time ownership snapshot of a [LevitScope]; later mutations
/// cannot change this view.
///
/// {@category Scopes & DI}
final class LevitScopeDescription {
  /// Unique runtime scope identifier.
  final int id;

  /// Diagnostic scope name.
  final String name;

  /// Whether terminal scope disposal has started.
  final bool isClosing;

  /// Whether terminal scope disposal has completed.
  final bool isDisposed;

  /// Total in-flight asynchronous initializations tracked by this scope.
  final int pendingInitializations;

  /// Ancestor scope identities ordered nearest ancestor first.
  final List<LevitScopeIdentity> ancestry;

  /// Directly owned child scope identities.
  final List<LevitScopeIdentity> ownedChildren;

  /// Local registrations and aliases present in this scope.
  final List<LevitRegistrationDescription> registrations;

  /// Creates an immutable scope ownership snapshot.
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

/// Optional SPI observer for scope initialization and closing progress without
/// exposing live dependency values.
///
/// Implement on a [LevitScopeMiddleware] registered with
/// [LevitScope.addMiddleware] to receive progress snapshots; errors thrown by
/// observers are isolated.
///
/// {@category SPI}
abstract interface class LevitScopeProgressObserver {
  /// Called whenever a scope's initialization or closing state changes.
  void onScopeProgress(LevitScopeDescription description);
}
