part of '../levit_dart_core.dart';

/// A base class for business logic components with automated resource management and explicit lifecycle hooks.
///
/// [LevitController] provides a structured environment for managing the lifecycle
/// of application logic. It implements [LevitScopeDisposable] to integrate
/// with the [Levit] dependency injection system.
///
/// The primary responsibility of a controller is to encapsulate business logic
/// and ensure that all resources (streams, timers, reactive variables) are
/// cleaned up when the controller is removed from its scope.
///
/// ### Lifecycle Lifecycle
/// 1.  **Construction**: The controller is instantiated.
/// 2.  **Attachment**: [didAttachToScope] is called when registered in a [LevitScope].
/// 3.  **Initialization**: [onInit] is called once after construction and attachment.
/// 4.  **Disposal**: [onClose] is called when the controller's scope is disposed or it is removed.
///
/// ### Automated Cleanup
/// Use [autoDispose] to register objects for automatic cleanup during [onClose].
/// This prevents memory leaks by ensuring resources are disposed in a deterministic order.
///
/// // Example usage:
/// ```dart
/// class MyController extends LevitController {
///   late final count = autoDispose(0.lx);
///
///   @override
///   void onInit() {
///     super.onInit();
///     // Start persistent listeners or fetch initial data
///   }
/// }
/// ```
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
            } catch (_) {}
          }
        }
      }
    }
  }

  /// Registers an [object] to be automatically cleaned up when this controller is closed.
  ///
  /// The [object] is returned to allow for inline chaining during initialization.
  ///
  /// ### Supported Types
  /// *   **[LxReactive]**: Invokes `close()`.
  /// *   **[StreamSubscription]**: Invokes `cancel()`.
  /// *   **[Timer]**: Invokes `cancel()`.
  /// *   **[Sink]**: Invokes `close()`.
  /// *   **Functions**: `void Function()` is called as a cleanup callback.
  /// *   **Duck Typing**: Objects with `dispose()`, `close()`, or `cancel()` methods.
  ///
  /// // Example usage:
  /// ```dart
  /// class MyController extends LevitController {
  ///   late final scrollController = autoDispose(ScrollController());
  ///   late final sub = autoDispose(myStream.listen((_) {}));
  /// }
  /// ```
  ///
  /// Returns the same [object] instance passed in.
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

  /// Callback invoked after the controller is instantiated and registered.
  ///
  /// Override this method to perform setup logic such as starting listeners,
  /// initializing reactive state, or pre-fetching data.
  ///
  /// Always call `super.onInit()` if overriding to ensure framework invariants.
  @override
  @mustCallSuper
  void onInit() {
    _initialized = true;
  }

  /// Callback invoked when the controller is being removed from [Levit].
  ///
  /// This method triggers the cleanup of all objects registered via [autoDispose].
  ///
  /// Always call `super.onClose()` if overriding. Once closed, the controller
  /// is considered disposed and cannot be reused.
  @override
  @mustCallSuper
  void onClose() {
    if (_closed) return;
    _closed = true;
    _disposed = true;

    for (final disposable in _disposables) {
      _levitDisposeItem(disposable);
    }
    _disposables.clear();
  }
}

/// Internal utility that detects and executes the appropriate cleanup method for an [item].
void _levitDisposeItem(dynamic item) {
  if (item == null) return;

  // 1. Framework Specifics (Priority)
  if (item is LxReactive) {
    item.close();
    return;
  }

  // 2. The "Cancel" Group (Async tasks)
  // Most common: StreamSubscription, Timer
  if (item is StreamSubscription) {
    item.cancel();
    return;
  }
  if (item is Timer) {
    item.cancel();
    return;
  }

  try {
    // Duck typing for other cancelables (like CancelableOperation)
    (item as dynamic).cancel();
    return;
  } on NoSuchMethodError {
    // Not cancelable, fall through
  } on Exception catch (e) {
    // Prevent crash during cleanup (only for Exceptions)
    dev.log('Levit: Error cancelling ${item.runtimeType}',
        error: e, name: 'levit_dart');
  }

  // 3. The "Dispose" Group (Flutter Controllers)
  // Most common: TextEditingController, ChangeNotifier, FocusNode
  try {
    (item as dynamic).dispose();
    return;
  } on NoSuchMethodError {
    // Not disposable, fall through
  } on Exception catch (e) {
    dev.log('Levit: Error disposing ${item.runtimeType}',
        error: e, name: 'levit_dart');
  }

  // 4. The "Close" Group (Sinks, BLoCs, IO)
  // Most common: StreamController, Sink, Bloc
  if (item is Sink) {
    item.close();
    return;
  }

  try {
    (item as dynamic).close();
    return;
  } on NoSuchMethodError {
    // Not closeable, fall through
  } on Exception catch (e) {
    dev.log('Levit: Error closing ${item.runtimeType}',
        error: e, name: 'levit_dart');
  }

  // 5. The "Callable" Group (Cleanup Callbacks)
  if (item is void Function()) {
    item();
    return;
  }
}
