part of '../levit_dart.dart';

// ============================================================================
// LevitController - Pure Dart Controller Base
// ============================================================================

/// A base class for business logic components with automated resource management.
///
/// [LevitController] provides a structured environment for managing the lifecycle
/// of your application's logic. It implements [LevitScopeDisposable] to integrate
/// seamlessly with the [Levit] dependency injection system.
///
/// ### Architecture Summary
/// The main purpose of a controller is to centralize logic and ensure that
/// resources (like streams, timers, or reactive variables) are cleaned up as
/// soon as the controller is no longer needed.
///
/// By using [autoDispose], you can register objects for automatic cleanup during
/// [onClose]. This prevents memory leaks and stale listeners without requiring
/// manual boilerplate.
///
/// While [LevitController] is a pure Dart class, it uses "duck typing" in its
/// cleanup logic to support disposing of common Flutter and IO types if they
/// are registered.
abstract class LevitController implements LevitScopeDisposable {
  bool _initialized = false;
  bool _disposed = false;
  bool _closed = false;
  final List<dynamic> _disposables = [];

  /// Returns `true` if [onInit] has been executed.
  bool get initialized => _initialized;

  /// Returns `true` if the controller has been disposed and closed.
  bool get isDisposed => _disposed;

  /// Returns `true` if the controller is in the process of closing or is closed.
  bool get isClosed => _closed;

  /// Returns `true` if the initialization phase is complete.
  bool get isInitialized => _initialized;

  /// The registration key used to identify this instance in [Levit].
  String? get registrationKey => _registrationKey;

  LevitScope? _scope;
  String? _registrationKey;

  /// The [LevitScope] that currently owns this controller.
  LevitScope? get scope => _scope;

  @override
  @mustCallSuper
  void didAttachToScope(LevitScope scope, {String? key}) {
    _scope = scope;
    _registrationKey = key;
  }

  /// Registers an [object] to be automatically cleaned up when this controller is closed.
  ///
  /// Supported cleanup patterns:
  /// *   **[LxReactive]**: Calls `.close()`.
  /// *   **[StreamSubscription]**: Calls `.cancel()`.
  /// *   **Callable**: `void Function()` is executed.
  /// *   **Disposable**: Any object with a `.dispose()` method (e.g., Flutter Controllers).
  /// *   **Closeable**: Any object with a `.close()` method (e.g., Sinks).
  /// *   **Cancelable**: Any object with a `.cancel()` method (e.g., Timers).
  ///
  /// Returns the [object] to allow for inline chaining:
  /// ```dart
  /// final count = autoDispose(0.lx);
  /// ```
  T autoDispose<T>(T object) {
    // Check for identity to allow equal-but-distinct reactive variables (since LxBase overrides ==)
    final alreadyAdded =
        _disposables.any((element) => identical(element, object));

    if (!alreadyAdded) {
      _disposables.add(object);
    }

    // Auto-linking: If the reactive object doesn't have an ownerId, adopt it.
    if (object is LxReactive) {
      if (object.ownerId == null) {
        object.ownerId = _registrationKey;
      }
    }

    return object;
  }

  /// Called after the controller is instantiated and registered.
  ///
  /// Override this method to perform setup logic, such as starting listeners
  /// or pre-fetching data.
  @override
  @mustCallSuper
  void onInit() {
    _initialized = true;
  }

  /// Called when the controller is being removed from [Levit].
  ///
  /// This method triggers the cleanup of all objects registered via [autoDispose].
  /// If you override this, call `super.onClose()` to ensure proper cleanup.
  @override
  @mustCallSuper
  void onClose() {
    if (_closed) return;
    _closed = true;
    _disposed = true;

    for (final disposable in _disposables) {
      _disposeItem(disposable);
    }
    _disposables.clear();
  }

  /// Internal utility that detects and executes the appropriate cleanup method for an [item].
  void _disposeItem(dynamic item) {
    if (item == null) return;

    // 1. Framework Specifics (Priority)
    if (item is LxReactive) {
      item.close();
      return;
    }

    // 2. The "Cancel" Group (Async tasks)
    // Most common: StreamSubscription, Timer
    try {
      if (item is StreamSubscription) {
        item.cancel();
        return;
      }
      // Duck typing for other cancelables (like Timer or CancelableOperation)
      (item as dynamic).cancel();
      return;
    } on NoSuchMethodError {
      // Not cancelable, fall through
    }

    // 3. The "Dispose" Group (Flutter Controllers)
    // Most common: TextEditingController, ChangeNotifier, FocusNode
    try {
      (item as dynamic).dispose();
      return;
    } on NoSuchMethodError {
      // Not disposable, fall through
    }

    // 4. The "Close" Group (Sinks, BLoCs, IO)
    // Most common: StreamController, Sink, Bloc
    try {
      (item as dynamic).close();
      return;
    } on NoSuchMethodError {
      // Not closeable, fall through
    }

    // 5. The "Callable" Group (Cleanup Callbacks)
    if (item is void Function()) {
      item();
      return;
    }
  }
}
