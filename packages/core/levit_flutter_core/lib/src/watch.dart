part of '../levit_flutter_core.dart';

/// A reactive widget that automatically rebuilds when accessed [LxReactive] values change.
///
/// [LWatch] is the primary bridge between the reactive state in your controllers
/// and the Flutter UI. It uses a "proxy-based tracking" mechanism to detect
/// which reactive variables are used during the execution of its [builder].
///
/// ### Usage
/// Simply wrap any widget that depends on reactive state in an [LWatch].
///
/// // Example usage:
/// ```dart
/// final count = 0.lx;
///
/// LWatch(() => Text('Count: ${count.value}'))
/// ```
class LWatch extends Widget {
  /// The builder function that constructs the reactive widget tree.
  final Widget Function() builder;

  /// An optional label for debugging and performance profiling.
  final String? debugLabel;

  /// Creates a reactive [LWatch] widget.
  const LWatch(this.builder, {super.key, this.debugLabel});

  @override
  Element createElement() => _LWatchElement(this);
}

class _LWatchElement extends ComponentElement implements LevitReactiveObserver {
  _LWatchElement(LWatch super.widget);

  @override
  void update(LWatch newWidget) {
    super.update(newWidget);
    markNeedsBuild(); // Force rebuild on update
    rebuild();
  }

  // Fast path for single notifier (most common case)
  LevitReactiveNotifier? _singleNotifier;
  bool _usingSinglePath = false;

  // Slow path for multiple dependencies
  Set<LevitReactiveNotifier>? _notifiers;

  // Optimized: Use List instead of Set for zero-allocation capture
  List<LevitReactiveNotifier>? _newNotifiers;

  bool _isDirty = false;

  @override
  void addNotifier(LevitReactiveNotifier notifier) {
    (_newNotifiers ??= []).add(notifier);
  }

  @override
  void addReactive(LxReactive reactive) {
    // No-op
  }

  void _cleanupAll() {
    if (_usingSinglePath) {
      _singleNotifier?.removeListener(_triggerRebuild);
      _singleNotifier = null;
      _usingSinglePath = false;
    }

    final nots = _notifiers;
    if (nots != null && nots.isNotEmpty) {
      for (final n in nots) {
        n.removeListener(_triggerRebuild);
      }
      nots.clear();
    }
  }

  void _triggerRebuild() {
    if (!_isDirty && mounted) {
      _isDirty = true;
      markNeedsBuild();
    }
  }

  @override
  Widget build() {
    if ((widget as LWatch).debugLabel != null) {
      assert(() {
        debugPrint('LWatch[${(widget as LWatch).debugLabel}] rebuilding');
        return true;
      }());
    }

    _isDirty = false;
    _newNotifiers = null;

    final previousProxy = Lx.proxy;
    Lx.proxy = this;

    final Widget result;
    try {
      result = (widget as LWatch).builder();
    } finally {
      Lx.proxy = previousProxy;
    }

    _updateSubscriptions(_newNotifiers);

    return result;
  }

  void _updateSubscriptions(List<LevitReactiveNotifier>? nextNotifiers) {
    // 1. FAST PATH: Single Notifier
    if (nextNotifiers != null && nextNotifiers.length == 1) {
      final notifier = nextNotifiers[0];
      if (_usingSinglePath && identical(_singleNotifier, notifier)) {
        return; // Exact match, zero work
      }

      _cleanupAll();
      _singleNotifier = notifier;
      _usingSinglePath = true;
      _runWithContext(() {
        notifier.addListener(_triggerRebuild);
      });
      return;
    }

    // 2. EMPTY PATH: No dependencies
    if (nextNotifiers == null) {
      if (_usingSinglePath || (_notifiers?.isNotEmpty ?? false)) {
        _runWithContext(_cleanupAll);
      }
      return;
    }

    // 3. SLOW PATH: Multiple Notifiers
    // Clean up fast path if used
    if (_usingSinglePath) {
      _singleNotifier?.removeListener(_triggerRebuild);
      _singleNotifier = null;
      _usingSinglePath = false;
    }

    // Process Notifiers
    final currentNots = _notifiers;
    final targetNots = _notifiers ??= {};

    // Add new
    for (var i = 0; i < nextNotifiers.length; i++) {
      final n = nextNotifiers[i];
      if (targetNots.add(n)) {
        _runWithContext(() {
          n.addListener(_triggerRebuild);
        });
      }
    }

    // Remove old
    if (currentNots != null && currentNots.isNotEmpty) {
      currentNots.removeWhere((notifier) {
        for (var i = 0; i < nextNotifiers.length; i++) {
          if (identical(notifier, nextNotifiers[i])) return false;
        }
        _runWithContext(() {
          notifier.removeListener(_triggerRebuild);
        });
        return true;
      });
    }
  }

  void _runWithContext(void Function() fn) {
    if (LevitReactiveMiddleware.hasListenerMiddlewares) {
      Lx.runWithContext(_buildContext(), fn);
    } else {
      fn();
    }
  }

  LxListenerContext _buildContext() {
    return LxListenerContext(
      type: 'LWatch',
      id: identityHashCode(this),
      data: {
        if ((widget as LWatch).debugLabel != null)
          'label': (widget as LWatch).debugLabel,
        'runtimeType': widget.runtimeType.toString(),
      },
    );
  }

  @override
  void unmount() {
    _runWithContext(_cleanupAll);
    super.unmount();
  }
}

/// A reactive widget that observes a single, specific reactive value.
///
/// Unlike [LWatch], which tracks dependencies automatically, [LWatchVar]
/// requires you to explicitly provide the reactive object to watch.
///
/// // Example usage:
/// ```dart
/// LWatchVar(myCount, (count) => Text('Value: ${count.value}'))
/// ```
class LWatchVar<T extends LxReactive> extends Widget {
  /// The builder function that receives the specific reactive instance [x].
  final Widget Function(T x) builder;

  /// The reactive instance to observe.
  final T x;

  /// Creates a widget that specifically watches the reactive object [x].
  const LWatchVar(this.x, this.builder, {super.key});

  @override
  Element createElement() => _LWatchVarElement<T>(this);
}

class _LWatchVarElement<T extends LxReactive> extends ComponentElement {
  _LWatchVarElement(LWatchVar<T> super.widget);

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _runWithContext(() {
      (widget as LWatchVar<T>).x.addListener(_onNotify);
    });
  }

  void _onNotify() {
    if (mounted) markNeedsBuild();
  }

  @override
  void update(LWatchVar<T> newWidget) {
    final oldWidget = widget as LWatchVar<T>;
    super.update(newWidget);
    if (newWidget.x != oldWidget.x) {
      _runWithContext(() {
        oldWidget.x.removeListener(_onNotify);
        newWidget.x.addListener(_onNotify);
      });
    }
    markNeedsBuild(); // Force rebuild
    rebuild();
  }

  @override
  Widget build() {
    return (widget as LWatchVar<T>).builder((widget as LWatchVar<T>).x);
  }

  @override
  void unmount() {
    _runWithContext(() {
      (widget as LWatchVar<T>).x.removeListener(_onNotify);
    });
    super.unmount();
  }

  void _runWithContext(void Function() fn) {
    if (LevitReactiveMiddleware.hasListenerMiddlewares) {
      Lx.runWithContext(_buildContext(), fn);
    } else {
      fn();
    }
  }

  LxListenerContext _buildContext() {
    return LxListenerContext(
      type: 'LWatchVar',
      id: identityHashCode(this),
      data: {'runtimeType': widget.runtimeType.toString()},
    );
  }
}

/// A reactive widget specialized for handling the various states of an [LxStatus].
///
/// [LWatchStatus] is a high-performance alternative for handling asynchronous
/// state transitions. It resolves the current state of [x] and calls the
/// corresponding builder.
///
/// // Example usage:
/// ```dart
/// LWatchStatus(
///   myStatusRx,
///   onSuccess: (data) => Text('Data: $data'),
///   onWaiting: () => CircularProgressIndicator(),
/// )
/// ```
class LWatchStatus<T> extends Widget {
  /// The reactive status source to watch.
  final LxReactive<LxStatus<T>> x;

  /// Builder for success state.
  final Widget Function(T data) onSuccess;

  /// Builder for waiting/loading state.
  final Widget Function()? onWaiting;

  /// Builder for error state.
  final Widget Function(Object error, StackTrace? stackTrace)? onError;

  /// Builder for idle state.
  final Widget Function()? onIdle;

  /// Creates a widget that specifically watches the status source [x].
  const LWatchStatus(
    this.x, {
    super.key,
    required this.onSuccess,
    this.onWaiting,
    this.onError,
    this.onIdle,
  });

  @override
  Element createElement() => LWatchStatusElement<T>(this);
}

class LWatchStatusElement<T> extends ComponentElement {
  LWatchStatusElement(LWatchStatus<T> super.widget);

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _runWithContext(() {
      (widget as LWatchStatus<T>).x.addListener(_onNotify);
    });
  }

  void _onNotify() {
    if (mounted) markNeedsBuild();
  }

  @override
  void update(LWatchStatus<T> newWidget) {
    final oldWidget = widget as LWatchStatus<T>;
    super.update(newWidget);
    if (newWidget.x != oldWidget.x) {
      _runWithContext(() {
        oldWidget.x.removeListener(_onNotify);
        newWidget.x.addListener(_onNotify);
      });
    }
    markNeedsBuild();
    rebuild();
  }

  @override
  Widget build() {
    final w = widget as LWatchStatus<T>;
    final status = w.x.value;

    return switch (status) {
      LxIdle<T>() =>
        w.onIdle?.call() ?? w.onWaiting?.call() ?? const SizedBox.shrink(),
      LxWaiting<T>() => w.onWaiting?.call() ?? const SizedBox.shrink(),
      LxError<T>(:final error, :final stackTrace) =>
        w.onError?.call(error, stackTrace) ??
            Center(child: Text('Error: $error')),
      LxSuccess<T>(:final value) => w.onSuccess(value),
    };
  }

  @override
  void unmount() {
    _runWithContext(() {
      (widget as LWatchStatus<T>).x.removeListener(_onNotify);
    });
    super.unmount();
  }

  void _runWithContext(void Function() fn) {
    if (LevitReactiveMiddleware.hasListenerMiddlewares) {
      Lx.runWithContext(_buildContext(), fn);
    } else {
      fn();
    }
  }

  LxListenerContext _buildContext() {
    return LxListenerContext(
      type: 'LWatchStatus',
      id: identityHashCode(this),
      data: {'runtimeType': widget.runtimeType.toString()},
    );
  }
}
