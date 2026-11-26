part of 'dart_core_library.dart';

final class _OwnerInitialization {
  _OwnerInitialization(this.owner);
  final LevitController owner;
  bool active = true;
}

/// A base class for lifecycle-aware business logic components.
///
/// [LevitController] manages the lifecycle of application logic, providing
/// automated resource cleanup and integration with the dependency injection
/// system.
///
/// Implementers should override [onInit] for setup, [onBeforeClose] for async
/// draining before owned resources close, and [onClose] for custom cleanup.
/// Always call `super.onInit()`, `await super.onBeforeClose()`, and
/// `await super.onClose()` in overrides. Use [own] to register non-reactive or
/// manually managed resources.
///
/// ```dart
/// class CounterController extends LevitController {
///   final count = 0.lx;
///
///   void increment() => count.value++;
/// }
/// ```
///
/// Prefer [LxWorker] + [own] (or auto-linking during [onInit]) for reload and
/// reaction side effects instead of raw `.stream.listen`:
///
/// ```dart
/// own(LxWorker(contextVar, (_) async {
///   await reload();
/// }));
/// ```
///
/// [LxWorker] is an [LxReactive], so [own] closes it with the controller.
///
/// Lifecycle:
/// 1. **Construction**: Instance created.
/// 2. **Initialization**: [onInit] runs before scope attachment (`scope` and
///    `registrationKey` are still `null`).
/// 3. **Attachment**: [didAttachToScope] binds [scope] and [registrationKey]
///    and reconciles owned reactive owner paths.
/// 4. **Pre-close & Drain**: [requestCancel] and [onBeforeClose] run before
///    owned resources close.
/// 5. **Disposal**: [onClose] disposes all resources registered via [own] in
///    reverse order when removed from the scope or when the owning scope closes.
///
/// {@category Controllers & Stores}
abstract class LevitController extends LevitScopeDisposable
    implements LevitDrainable, LevitExecutionBoundary {
  bool _initialized = false;
  bool _resourceClosing = false;
  bool _resourceDisposed = false;
  LinkedHashSet<Object>? _ownedResourcesStorage;
  Map<Object, FutureOr<void> Function()>? _disposers;
  List<LevitDisposalFailure>? _requestFailures;
  Set<Future<void>>? _capturedInitializations;
  Future<void>? _resourceDrainFuture;
  Completer<void>? _resourceDisposedCompleter;
  Future<void>? _resourceCloseFuture;
  static final Object _initializationZone = Object();

  LevitScope? _scope;
  String? _registrationKey;
  String? _cachedOwnerPath;

  /// Whether controller cleanup has started.
  bool get isClosing => _resourceClosing;

  /// Whether cleanup has completed.
  bool get isDisposed => _resourceDisposed;

  /// Completes when cleanup reaches its terminal state.
  Future<void> get disposed {
    final completed = _resourceDisposedCompleter ??= Completer<void>();
    if (_resourceDisposed && !completed.isCompleted) completed.complete();
    return completed.future;
  }

  /// Whether this controller has started closing or has finished disposing.
  ///
  /// Equivalent to `isClosing || isDisposed`. Use this for cooperative async
  /// guards after `await`; inspect [isClosing] or [isDisposed] when you need to
  /// distinguish active teardown from completed disposal.
  bool get isClosed => isClosing || isDisposed;

  /// Whether `super.onInit()` has executed on this controller.
  ///
  /// Flips synchronously inside `super.onInit()` and does not wait for
  /// asynchronous work started by subclasses.
  bool get isInitialized => _initialized;

  /// The registration key assigned to this instance in its owning [scope], or
  /// `null` before [didAttachToScope] runs.
  String? get registrationKey => _registrationKey;

  /// The [LevitScope] that currently owns this controller.
  LevitScope? get scope => _scope;

  /// The full owner path within the monitoring system (`scopeId:registrationKey`).
  String get ownerPath {
    final s = _scope;
    final r = _registrationKey;
    if (s == null || r == null) return r ?? '?';
    return _cachedOwnerPath ??= '${s.id}:$r';
  }

  /// Resources currently tracked by this controller.
  @protected
  Iterable<Object> get ownedResources =>
      _ownedResourcesStorage ?? const Iterable<Object>.empty();

  /// Registers [resource] for deterministic cleanup when this controller closes
  /// and returns it.
  ///
  /// Built-in adapters handle [LxReactive], [LevitScopeDisposable],
  /// [LevitDisposable], [StreamSubscription], [Timer], [Sink], and
  /// `FutureOr<void> Function()` cleanup callbacks. Platform integrations (such
  /// as `levit_flutter_core` for Flutter's `ChangeNotifier`) may register
  /// additional adapters. For other types, supply an explicit [dispose]
  /// callback.
  T own<T>(T resource, {FutureOr<void> Function(T resource)? dispose}) {
    if (_resourceClosing || _resourceDisposed) {
      throw StateError(
        '${runtimeType.toString()} cannot own resources after closing.',
      );
    }
    if (resource == null) return resource;

    final object = resource as Object;
    if (dispose == null && !Levit._canDisposeItem(object)) {
      throw ArgumentError(
        'Supply an explicit dispose callback for ${object.runtimeType}.',
        'resource',
      );
    }
    final owned = _ownedResourcesStorage ??= LinkedHashSet<Object>.identity();
    if (owned.add(object) && dispose != null) {
      (_disposers ??= Map.identity())[object] = () => dispose(resource);
    }

    if (object is LxReactive && object.ownerId == null) {
      object.ownerId = ownerPath;
    }
    return resource;
  }

  /// Creates a synchronous [LxComputed] and registers it with [own].
  ///
  /// Enables concise derived fields without an [onInit] override:
  /// ```dart
  /// late final fullName = computed(() => '${firstName()} ${lastName()}');
  /// ```
  LxComputed<T> computed<T>(
    T Function() compute, {
    bool Function(T previous, T current)? equals,
    bool staticDeps = false,
    bool eager = false,
    String? name,
  }) => own(
    LxComputed<T>(
      compute,
      equals: equals,
      staticDeps: staticDeps,
      eager: eager,
      name: name,
    ),
  );

  /// Creates an asynchronous [LxAsyncComputed] and registers it with [own].
  ///
  /// Enables concise async derived fields without an [onInit] override:
  /// ```dart
  /// late final results = asyncComputed(() => api.search(query()));
  /// ```
  LxAsyncComputed<T> asyncComputed<T>(
    Future<T> Function() compute, {
    bool Function(T previous, T current)? equals,
    bool showWaiting = false,
    bool staticDeps = false,
    T? initial,
    String? name,
    LxAsyncConcurrency concurrency = LxAsyncConcurrency.latest,
  }) => own(
    LxAsyncComputed<T>(
      compute,
      equals: equals,
      showWaiting: showWaiting,
      staticDeps: staticDeps,
      initial: initial,
      name: name,
      concurrency: concurrency,
    ),
  );

  R _runInitialization<R>(R Function() initialize) {
    final execution = _OwnerInitialization(this);
    try {
      final result = runZoned(
        initialize,
        zoneValues: {
          _initializationZone: [
            ...?Zone.current[_initializationZone]
                as List<_OwnerInitialization>?,
            execution,
          ],
        },
      );
      if (result is Future) {
        unawaited(
          result.then<void>(
            (_) {
              execution.active = false;
            },
            onError: (Object _, StackTrace __) {
              execution.active = false;
            },
          ),
        );
      } else {
        execution.active = false;
      }
      return result;
    } catch (_) {
      execution.active = false;
      rethrow;
    }
  }

  // Only the initialization capture mechanism may adopt resources after
  // cancellation. Its tracked future keeps the controller alive until adoption ends.
  void _adoptCaptured(LxReactive resource) {
    if (_resourceDisposed) {
      throw StateError('Initialization outlived its owner.');
    }
    final owned = _ownedResourcesStorage ??= LinkedHashSet<Object>.identity();
    if (owned.add(resource)) {
      resource.ownerId ??= ownerPath;
    }
  }

  void _trackCapturedInitialization(Future<void> operation) {
    final trackedSet = _capturedInitializations ??= {};
    late final Future<void> tracked;
    tracked = operation
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            (_requestFailures ??= []).add(
              LevitDisposalFailure(
                resource: this,
                error: error,
                stackTrace: stack,
              ),
            );
          },
        )
        .whenComplete(() => trackedSet.remove(tracked));
    trackedSet.add(tracked);
  }

  /// Reconciles already-owned reactive diagnostics after scope attachment.
  @protected
  void refreshOwnedReactivePaths() {
    final owned = _ownedResourcesStorage;
    if (owned == null) return;
    for (final resource in owned) {
      if (resource is LxReactive && resource.ownerId != ownerPath) {
        resource.ownerId = ownerPath;
        resource.refresh();
      }
    }
  }

  /// Attaches this controller to an owning [scope] with an optional registration [key].
  ///
  /// Called once by the DI runtime immediately after [onInit] when the
  /// controller is instantiated (during `put` or on first resolution of
  /// `lazyPut`/`lazyPutAsync`). Updates ownership metadata for already tracked
  /// reactive resources so diagnostics and disposal ownership remain accurate.
  ///
  /// Subclasses that override this method must call `super.didAttachToScope`.
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

  /// Executes [action] and suppresses its result if this controller closes first.
  ///
  /// This is a cooperative lifecycle guard: it does not cancel the underlying
  /// operation, but it prevents stale post-await code from using a result after
  /// disposal when [discardResultOnClose] is `true`.
  ///
  /// If [discardResultOnClose] is `true` and the controller is already closed, this
  /// method returns `null` without invoking [action].
  ///
  /// If [onError] is provided, it is called before re-throwing any error from [action].
  ///
  /// Returns the computed value when still valid for this lifecycle, otherwise `null`.
  ///
  /// Throws any error thrown by [action].
  Future<T?> runGuardedAsync<T>(
    FutureOr<T> Function() action, {
    bool discardResultOnClose = true,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (discardResultOnClose && isClosed) return null;

    try {
      final result = await action();
      if (discardResultOnClose && isClosed) return null;
      return result;
    } catch (e, s) {
      onError?.call(e, s);
      rethrow;
    }
  }

  /// Called immediately after the controller is instantiated, before [didAttachToScope].
  ///
  /// Override to perform setup logic such as starting initial loads or
  /// registering workers via [own]. Subclasses must call `super.onInit()`.
  @override
  @mustCallSuper
  void onInit() {
    _initialized = true;
  }

  /// Runs after closing begins and before any owned resources are released.
  ///
  /// Override to await work that still uses owned resources. Always delegate
  /// to `super.onBeforeClose()`. Do not await this controller's disposal from
  /// work being drained.
  @protected
  @mustCallSuper
  FutureOr<void> onBeforeClose() {}

  /// Called when the controller is removed from its scope or its owning scope is disposed.
  ///
  /// Drains active work and releases all resources registered via [own] in
  /// reverse order. Subclasses overriding this method must `await` or return
  /// `super.onClose()`.
  @override
  @mustCallSuper
  FutureOr<void> onClose() {
    assertCanDispose();
    return _resourceCloseFuture ??= _closeOwnedResources();
  }

  /// Rejects cleanup from a callback owned by this controller.
  @override
  @protected
  void assertCanDispose() {
    final initializing =
        Zone.current[_initializationZone] as List<_OwnerInitialization>?;
    if (initializing?.any(
          (execution) => execution.active && identical(execution.owner, this),
        ) ??
        false) {
      throw StateError(
        'Initialization cannot dispose its own owner; request cancellation instead.',
      );
    }
    final owned = _ownedResourcesStorage;
    if (owned != null) {
      for (final resource in owned) {
        if (resource is LevitExecutionBoundary) resource.assertCanDispose();
      }
      if (owned.any(LxSpi.isExecuting)) {
        throw StateError(
          'Owned work cannot dispose its own owner; request cancellation instead.',
        );
      }
    }
  }

  @override
  void requestCancel() {
    if (_resourceClosing) return;
    _resourceClosing = true;
    final owned = _ownedResourcesStorage;
    if (owned == null || owned.isEmpty) return;
    for (final resource in owned.toList(growable: false)) {
      try {
        if (resource is LxAsyncResource) resource.requestCancel();
        if (resource is LevitDrainable) resource.requestCancel();
        if (resource is Timer) resource.cancel();
      } catch (error, stackTrace) {
        (_requestFailures ??= []).add(
          LevitDisposalFailure(
            resource: resource,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }
  }

  @override
  Future<void> drain() {
    assertCanDispose();
    requestCancel();
    return _resourceDrainFuture ??= _drainOwnedWork();
  }

  Future<void> _drainOwnedWork() async {
    final captured = _capturedInitializations;
    if (captured != null) {
      while (captured.isNotEmpty) {
        await Future.wait(captured.toList());
      }
    }
    final failures = <LevitDisposalFailure>[...?_requestFailures];
    final owned = _ownedResourcesStorage;
    if (owned != null && owned.isNotEmpty) {
      for (final resource in owned.toList(growable: false)) {
        // Capture runs during constructors; only cancel newly adopted producers
        // once initialization has completed and their fields are initialized.
        try {
          if (resource is LxAsyncResource) resource.requestCancel();
          if (resource is LevitDrainable) resource.requestCancel();
        } catch (error, stackTrace) {
          failures.add(
            LevitDisposalFailure(
              resource: resource,
              error: error,
              stackTrace: stackTrace,
            ),
          );
        }
      }
    }
    Future<void> attempt(
      Object resource,
      FutureOr<void> Function() operation,
    ) async {
      try {
        await operation();
      } on LevitDisposalException catch (error) {
        failures.addAll(error.failures);
      } catch (error, stackTrace) {
        failures.add(
          LevitDisposalFailure(
            resource: resource,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }

    await attempt(this, onBeforeClose);
    final drainOwned = _ownedResourcesStorage;
    if (drainOwned != null && drainOwned.isNotEmpty) {
      for (final resource in drainOwned.toList(growable: false).reversed) {
        if (resource is LxAsyncResource) {
          if (resource is! LxVar || !LxSpi.isDrainedSync(resource)) {
            await attempt(resource, resource.drain);
          }
        }
        if (resource is LevitDrainable) {
          await attempt(resource, resource.drain);
        }
      }
    }
    if (failures.isNotEmpty) throw LevitDisposalException.aggregate(failures);
  }

  Future<void> _closeOwnedResources() async {
    if (_resourceDisposed) return;
    final failures = <LevitDisposalFailure>[];
    try {
      await drain();
    } on LevitDisposalException catch (error) {
      failures.addAll(error.failures);
    } catch (error, stackTrace) {
      failures.add(
        LevitDisposalFailure(
          resource: this,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
    final owned = _ownedResourcesStorage;
    if (owned != null && owned.isNotEmpty) {
      final disposers = _disposers;
      for (final resource in owned.toList(growable: false).reversed) {
        try {
          final disposer = disposers?[resource];
          final cleanup =
              disposer != null ? disposer() : Levit._levitDisposeItem(resource);
          if (cleanup is Future) {
            await cleanup;
          }
        } on LevitDisposalException catch (error) {
          failures.addAll(error.failures);
        } catch (error, stackTrace) {
          if (!failures.any(
            (failure) =>
                identical(failure.resource, resource) &&
                identical(failure.error, error),
          )) {
            failures.add(
              LevitDisposalFailure(
                resource: resource,
                error: error,
                stackTrace: stackTrace,
              ),
            );
          }
        }
      }
      owned.clear();
    }
    _disposers?.clear();
    _resourceDisposed = true;
    _resourceDisposedCompleter?.complete();
    if (failures.isNotEmpty) throw LevitDisposalException.aggregate(failures);
  }
}
