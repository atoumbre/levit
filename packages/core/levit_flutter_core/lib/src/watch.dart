part of '../levit_flutter_core.dart';

/// A widget that rebuilds when reactive state changes.
///
/// [LWatch] tracks which [LxReactive] values are accessed within its [builder]
/// and automatically triggers a rebuild when any of them change.
///
/// Example:
/// ```dart
/// LWatch(() {
///   return Text('Count: ${controller.count()}');
/// });
/// ```
class LWatch extends Widget {
  /// The builder function used to generate the widget tree.
  final Widget Function() builder;

  /// A debug label used for profiling and logging.
  final String? debugLabel;

  /// Creates a reactive widget.
  const LWatch(this.builder, {super.key, this.debugLabel});

  @override
  Element createElement() => _LWatchElement(this);
}

class _LWatchElement extends ComponentElement implements LevitReactiveObserver {
  _LWatchElement(LWatch super.widget);

  @override
  void update(LWatch newWidget) {
    final oldWidget = widget as LWatch;
    super.update(newWidget);
    if (oldWidget.debugLabel != newWidget.debugLabel) {
      _cachedContext = null;
    }
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
  final Set<LevitReactiveNotifier> _scratchNotifiers = {};
  LxListenerContext? _cachedContext;

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
      result = LScope.runBridged(this, () => (widget as LWatch).builder());
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

    // Process notifiers with reusable scratch set (avoid per-build toSet allocation)
    final targetNots = _notifiers ??= {};
    _scratchNotifiers.clear();

    // Add new / keep current
    for (final n in nextNotifiers) {
      if (!_scratchNotifiers.add(n)) continue;
      if (targetNots.add(n)) {
        _runWithContext(() {
          n.addListener(_triggerRebuild);
        });
      }
    }

    // Remove stale
    if (targetNots.isNotEmpty) {
      targetNots.removeWhere((notifier) {
        if (_scratchNotifiers.contains(notifier)) return false;
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
    return _cachedContext ??= LxListenerContext(
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
