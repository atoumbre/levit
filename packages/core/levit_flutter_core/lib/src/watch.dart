part of '../levit_flutter_core.dart';

/// A widget that rebuilds when reactive state changes.
///
/// [LWatch] tracks which [LxReadable] values are accessed during each execution
/// of [builder] (dynamically reconciling conditional reads) and automatically
/// triggers a rebuild when any tracked source notifies. Wrap reads in
/// [Levit.untracked] to read without subscribing.
///
/// When inside an [LView] or [LScopedView] with `autoWatch: true` (default),
/// do not wrap the entire return tree in an outer [LWatch]; use nested [LWatch]
/// only for narrower partial rebuilds.
///
/// ```dart
/// LWatch(() {
///   return Text('Count: ${controller.count()}');
/// });
/// ```
///
/// {@category Flutter Widgets & Interop}
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

class _LWatchElement extends ComponentElement
    implements LevitReactiveObserver, LevitReactiveReadResolver {
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

  // Single-dependency fast path avoids set allocations and diffing.
  LevitReactiveNotifier? _singleNotifier;
  bool _usingSinglePath = false;

  // Multi-dependency path keeps a stable subscription set.
  Set<LevitReactiveNotifier>? _notifiers;
  Map<(Type, String, String), LxReactive?>? _logicalReactiveIndex;

  // Builder capture uses list semantics; duplicates are deduped later.
  List<LevitReactiveNotifier>? _newNotifiers;
  final Set<LevitReactiveNotifier> _scratchNotifiers = {};
  LxListenerContext? _cachedContext;

  @override
  void addNotifier(LevitReactiveNotifier notifier) {
    (_newNotifiers ??= []).add(notifier);
  }

  @override
  void addReactive(LxReactive reactive) {
    // Graph-only tracking is not required for widget rebuild subscriptions.
  }

  @override
  LxReactive resolveReactiveRead(LxReactive reactive) {
    // Stabilize reads when a getter recreates wrapper reactives every build
    // but they still represent the same logical source.
    final single = _singleNotifier;
    if (_usingSinglePath &&
        single != null &&
        !single.isDisposed &&
        single is LxReactive) {
      final stable = single as LxReactive;
      if (_isSameLogicalReactive(stable, reactive)) {
        return stable;
      }
    }

    final nots = _notifiers;
    if (nots == null || nots.isEmpty) return reactive;

    final key = _logicalKeyOf(reactive);
    if (key == null) return reactive;

    final candidate = _logicalReactiveIndex?[key];
    if (candidate == null ||
        (candidate is LevitReactiveNotifier &&
            (candidate as LevitReactiveNotifier).isDisposed)) {
      return reactive;
    }
    return candidate;
  }

  bool _isSameLogicalReactive(LxReactive a, LxReactive b) {
    if (identical(a, b)) return true;
    if (a.runtimeType != b.runtimeType) return false;
    if (a is LevitReactiveNotifier && (a as LevitReactiveNotifier).isDisposed) {
      return false;
    }
    if (b is LevitReactiveNotifier && (b as LevitReactiveNotifier).isDisposed) {
      return false;
    }

    // Keep aliasing conservative to avoid cross-wiring unrelated reactives.
    final ownerA = a.ownerId;
    final ownerB = b.ownerId;
    final nameA = a.name;
    final nameB = b.name;

    if (ownerA == null ||
        ownerB == null ||
        ownerA == '?' ||
        ownerB == '?' ||
        nameA == null ||
        nameB == null) {
      return false;
    }

    return ownerA == ownerB && nameA == nameB;
  }

  (Type, String, String)? _logicalKeyOf(LxReactive reactive) {
    final ownerId = reactive.ownerId;
    final name = reactive.name;
    if (ownerId == null || ownerId == '?' || name == null) return null;
    return (reactive.runtimeType, ownerId, name);
  }

  void _rebuildLogicalReactiveIndex(Iterable<LevitReactiveNotifier> notifiers) {
    Map<(Type, String, String), LxReactive?>? next;

    for (final notifier in notifiers) {
      if (notifier.isDisposed || notifier is! LxReactive) continue;
      final reactive = notifier as LxReactive;
      final key = _logicalKeyOf(reactive);
      if (key == null) continue;

      next ??= <(Type, String, String), LxReactive?>{};
      final existing = next[key];
      if (!next.containsKey(key)) {
        next[key] = reactive;
      } else if (!identical(existing, notifier)) {
        next[key] = null;
      }
    }

    _logicalReactiveIndex = next;
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
    _logicalReactiveIndex = null;
  }

  void _triggerRebuild() {
    if (mounted) {
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

    _newNotifiers = null;

    final previousProxy = LxSpi.proxy;
    if (identical(previousProxy, this)) {
      // Force-reset read dedupe cache for a fresh dependency capture cycle.
      LxSpi.proxy = null;
    }
    LxSpi.proxy = this;

    final Widget result;
    try {
      result = LScope.runBridged(this, () => (widget as LWatch).builder());
    } finally {
      LxSpi.proxy = previousProxy;
    }

    _updateSubscriptions(_newNotifiers);

    return result;
  }

  void _updateSubscriptions(List<LevitReactiveNotifier>? nextNotifiers) {
    // Single dependency can be swapped with constant-time checks.
    if (nextNotifiers != null && nextNotifiers.length == 1) {
      final notifier = nextNotifiers[0];
      if (_usingSinglePath && identical(_singleNotifier, notifier)) {
        return; // No subscription changes.
      }

      _cleanupAll();
      _singleNotifier = notifier;
      _usingSinglePath = true;
      _runWithContext(() {
        notifier.addListener(_triggerRebuild);
      });
      return;
    }

    // No dependencies means the watch should hold no subscriptions.
    if (nextNotifiers == null) {
      if (_usingSinglePath || (_notifiers?.isNotEmpty ?? false)) {
        _runWithContext(_cleanupAll);
      }
      return;
    }

    // Multi-dependency reconciliation path.
    if (_usingSinglePath) {
      _singleNotifier?.removeListener(_triggerRebuild);
      _singleNotifier = null;
      _usingSinglePath = false;
    }

    // Scratch set enables dedupe without allocating a new set each build.
    final targetNots = _notifiers ??= {};
    _scratchNotifiers.clear();

    // Subscribe new dependencies and keep existing ones.
    for (final n in nextNotifiers) {
      if (!_scratchNotifiers.add(n)) continue;
      if (targetNots.add(n)) {
        _runWithContext(() {
          n.addListener(_triggerRebuild);
        });
      }
    }

    // Unsubscribe dependencies no longer observed by the builder.
    if (targetNots.isNotEmpty) {
      targetNots.removeWhere((notifier) {
        if (_scratchNotifiers.contains(notifier)) return false;
        _runWithContext(() {
          notifier.removeListener(_triggerRebuild);
        });
        return true;
      });
    }

    _rebuildLogicalReactiveIndex(targetNots);
  }

  void _runWithContext(void Function() fn) {
    if (LxSpi.hasListenerMiddlewares) {
      LxSpi.runWithContext(_buildContext(), fn);
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
