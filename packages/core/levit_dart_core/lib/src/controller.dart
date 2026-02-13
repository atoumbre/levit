part of '../levit_dart_core.dart';

/// A base class for business logic components.
///
/// [LevitController] manages the lifecycle of application logic, providing
/// automated resource cleanup and integration with the dependency injection system.
///
/// Implementers should override [onInit] for setup and [onClose] for cleanup.
/// Use [autoDispose] to simplify resource management.
///
/// Example:
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
/// Lifecycle:
/// 1.  **Construction**: Instance created.
/// 2.  **Attachment**: Linked to a [LevitScope].
/// 3.  **Initialization**: [onInit] called.
/// 4.  **Disposal**: [onClose] called when scope closes.
abstract class LevitController implements LevitScopeDisposable {
  bool _initialized = false;
  bool _disposed = false;
  bool _closed = false;
  final List<dynamic> _disposables = [];

  /// Whether [onInit] has been executed.
  bool get initialized => _initialized;

  /// Whether the controller has been disposed and closed.
  bool get isDisposed => _disposed;

  /// Whether the controller is in the process of closing or is closed.
  bool get isClosed => _closed;

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

    // Retroactively update ownerId for auto-disposed reactives
    // This handles the case where variables are initialized before attachment
    if (key != null) {
      _cachedOwnerPath = null; // Force recalculation if key changed
      final path = ownerPath;
      for (final item in _disposables) {
        if (item is LxReactive) {
          if (item.ownerId != path) {
            item.ownerId = path;
            try {
              item.refresh();
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
  /// Example:
  /// ```dart
  /// late final sub = autoDispose(stream.listen((_) {}));
  /// ```
  T autoDispose<T>(T object) {
    // Check for identity to allow equal-but-distinct reactive variables
    final alreadyAdded =
        _disposables.any((element) => identical(element, object));

    if (!alreadyAdded) {
      _disposables.add(object);
    }

    // Auto-linking: If the reactive object doesn't have an ownerId, adopt it.
    if (object is LxReactive) {
      if (object.ownerId == null) {
        object.ownerId = ownerPath;
      }
    }

    return object;
  }

  /// Executes [action] and suppresses its result if this controller closes first.
  ///
  /// This is a cooperative lifecycle guard: it does not cancel the underlying
  /// operation, but it prevents stale post-await code from using a result after
  /// disposal when [cancelOnClose] is `true`.
  ///
  /// If [cancelOnClose] is `true` and the controller is already closed, this
  /// method returns `null` without invoking [action].
  ///
  /// If [onError] is provided, it is called before rethrowing any error from [action].
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
  void onClose() {
    if (_closed) return;
    _closed = true;
    _disposed = true;

    for (final disposable in _disposables) {
      try {
        Levit._levitDisposeItem(disposable);
      } catch (e, s) {
        dev.log(
          'LevitController: failed to dispose ${disposable.runtimeType}',
          name: 'levit_dart',
          error: e,
          stackTrace: s,
        );
      }
    }
    _disposables.clear();
  }
}
