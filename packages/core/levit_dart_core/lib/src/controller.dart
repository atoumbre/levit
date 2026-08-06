part of '../levit_dart_core.dart';

/// A lifecycle boundary that owns arbitrary cleanup resources.
abstract interface class LevitResourceOwner {
  /// Registers [resource] for deterministic cleanup and returns it.
  T own<T>(T resource);

  /// Compatibility alias for [own].
  T autoDispose<T>(T resource);

  /// Whether cleanup has completed.
  bool get isDisposed;

  /// Completes when cleanup reaches its terminal state.
  Future<void> get disposed;
}

/// Reusable implementation of [LevitResourceOwner].
///
/// Apply this mixin to a [LevitScopeDisposable] when a non-controller resource
/// needs the same ownership semantics as [LevitController].
mixin LevitResourceOwnership on LevitScopeDisposable
    implements LevitResourceOwner {
  bool _resourceClosing = false;
  bool _resourceDisposed = false;
  final List<Object> _ownedResources = <Object>[];
  final Completer<void> _resourceDisposedCompleter = Completer<void>();
  Future<void>? _resourceCloseFuture;

  /// A diagnostic owner path applied to otherwise unnamed reactive resources.
  @protected
  String get resourceOwnerPath => '?';

  /// Whether owner cleanup has started.
  bool get isClosing => _resourceClosing;

  @override
  bool get isDisposed => _resourceDisposed;

  @override
  Future<void> get disposed => _resourceDisposedCompleter.future;

  /// Resources currently tracked by this owner.
  @protected
  Iterable<Object> get ownedResources => _ownedResources;

  @override
  T own<T>(T resource) {
    if (_resourceClosing || _resourceDisposed) {
      throw StateError(
        '${runtimeType.toString()} cannot own resources after closing.',
      );
    }
    if (resource == null) return resource;

    final object = resource as Object;
    final alreadyOwned =
        _ownedResources.any((candidate) => identical(candidate, object));
    if (!alreadyOwned) {
      _ownedResources.add(object);
    }

    if (object is LxReactive && object.ownerId == null) {
      object.ownerId = resourceOwnerPath;
    }
    return resource;
  }

  @override
  T autoDispose<T>(T resource) => own(resource);

  /// Reconciles already-owned reactive diagnostics after scope attachment.
  @protected
  void refreshOwnedReactivePaths() {
    for (final resource in _ownedResources) {
      if (resource is LxReactive && resource.ownerId != resourceOwnerPath) {
        resource.ownerId = resourceOwnerPath;
        resource.refresh();
      }
    }
  }

  @override
  @mustCallSuper
  FutureOr<void> onClose() {
    return _resourceCloseFuture ??= _closeOwnedResources();
  }

  Future<void> _closeOwnedResources() async {
    if (_resourceDisposed) return;
    _resourceClosing = true;
    final failures = <LevitDisposalFailure>[];

    for (final resource in _ownedResources.reversed.toList(growable: false)) {
      try {
        final result = Levit._levitDisposeItem(resource);
        if (result is Future) {
          await result;
        }
      } catch (error, stackTrace) {
        failures.add(LevitDisposalFailure(
          resource: resource,
          error: error,
          stackTrace: stackTrace,
        ));
      }
    }
    _ownedResources.clear();
    _resourceDisposed = true;
    if (!_resourceDisposedCompleter.isCompleted) {
      _resourceDisposedCompleter.complete();
    }

    if (failures.isNotEmpty) {
      throw LevitDisposalException(failures);
    }
  }
}

/// A base class for business logic components.
///
/// [LevitController] manages the lifecycle of application logic, providing
/// automated resource cleanup and integration with the dependency injection system.
///
/// Implementers should override [onInit] for setup and [onClose] for cleanup.
/// Use [autoDispose] to simplify resource management.
///
/// // Example usage:
/// ```dart
/// class CounterController extends LevitController {
///   final count = 0.lx;
///
///   @override
///   void onInit() {
///     autoDispose(count); // Cleanup on close
///   }
/// }
/// ```
///
/// Prefer [LxWorker] + [autoDispose] for reload / reaction side effects instead
/// of raw `.stream.listen`:
///
/// ```dart
/// autoDispose(LxWorker(contextVar, (_) async {
///   await reload();
/// }));
/// ```
///
/// [LxWorker] is an [LxReactive], so [autoDispose] closes it with the controller.
///
/// Lifecycle:
/// 1.  **Construction**: Instance created.
/// 2.  **Attachment**: Linked to a [LevitScope].
/// 3.  **Initialization**: [onInit] called.
/// 4.  **Disposal**: [onClose] called when scope closes.
abstract class LevitController extends LevitScopeDisposable
    with LevitResourceOwnership {
  bool _initialized = false;

  /// Whether [onInit] has been executed.
  bool get initialized => _initialized;

  /// Whether the controller has been disposed and closed.
  bool get isClosed => isClosing || isDisposed;

  /// Whether the initialization phase is complete.
  bool get isInitialized => _initialized;

  /// The registration key used to identify this instance in [Levit].
  String? get registrationKey => _registrationKey;

  LevitScope? _scope;
  String? _registrationKey;
  String? _cachedOwnerPath;

  /// The [LevitScope] that currently owns this controller.
  LevitScope? get scope => _scope;

  /// The full owner path within the monitoring system (scopeId:registrationKey).
  String get ownerPath {
    final s = _scope;
    final r = _registrationKey;
    if (s == null || r == null) return r ?? '?';
    return _cachedOwnerPath ??= '${s.id}:$r';
  }

  @override
  String get resourceOwnerPath => ownerPath;

  /// Attaches this controller to an owning [scope] with an optional registration [key].
  ///
  /// This method is called by the DI runtime when the controller is resolved.
  /// It updates ownership metadata for already tracked reactive resources so
  /// diagnostics and disposal ownership remain accurate.
  ///
  /// Throws no exceptions intentionally; internal failures are logged.
  @override
  @mustCallSuper
  void didAttachToScope(LevitScope scope, {String? key}) {
    _scope = scope;
    _registrationKey = key;

    // Attachment may happen after reactive creation; ownership must be reconciled.
    if (key != null) {
      _cachedOwnerPath = null; // Force recalculation if key changed
      try {
        refreshOwnedReactivePaths();
      } catch (e, s) {
        dev.log(
          'LevitController: failed to refresh auto-linked reactive',
          name: 'levit_dart',
          error: e,
          stackTrace: s,
        );
      }
    }
  }

  /// Registers [object] for automatic cleanup when the controller closes.
  ///
  /// Supports:
  /// *   [LxReactive] (closes the reactive)
  /// *   [StreamSubscription] (cancels subscription)
  /// *   [Timer] (cancels timer)
  /// *   [Sink] (closes sink)
  /// *   Anything with a `dispose()`, `close()`, or `cancel()` method.
  ///
  /// Returns the [object] to allow inline use during initialization.
  ///
  /// // Example usage:
  /// ```dart
  /// late final sub = autoDispose(stream.listen((_) {}));
  /// ```
  T autoDispose<T>(T object) => own(object);

  /// Executes [action] and suppresses its result if this controller closes first.
  ///
  /// This is a cooperative lifecycle guard: it does not cancel the underlying
  /// operation, but it prevents stale post-await code from using a result after
  /// disposal when [cancelOnClose] is `true`.
  ///
  /// If [cancelOnClose] is `true` and the controller is already closed, this
  /// method returns `null` without invoking [action].
  ///
  /// If [onError] is provided, it is called before re-throwing any error from [action].
  ///
  /// Returns the computed value when still valid for this lifecycle, otherwise `null`.
  ///
  /// Throws any error thrown by [action].
  Future<T?> runGuardedAsync<T>(
    FutureOr<T> Function() action, {
    bool cancelOnClose = true,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (cancelOnClose && isClosed) return null;

    try {
      final result = await action();
      if (cancelOnClose && isClosed) return null;
      return result;
    } catch (e, s) {
      onError?.call(e, s);
      rethrow;
    }
  }

  /// Called immediately after the controller is initialized.
  ///
  /// Override to perform setup logic like starting API calls or setting up listeners.
  /// Use [autoDispose] here to ensure resources are tracked.
  @override
  @mustCallSuper
  void onInit() {
    _initialized = true;
  }

  /// Called when the controller is removed from memory.
  ///
  /// Releases all resources registered via [autoDispose].
  /// Override to perform additional custom cleanup.
  @override
  @mustCallSuper
  FutureOr<void> onClose() => super.onClose();
}
