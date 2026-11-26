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
    rebuild(force: true);
  }

  // Single-dependency fast path avoids list/set allocations and diffing.
  LevitReactiveNotifier? _singleNotifier;
  bool _usingSinglePath = false;
  bool _expectingSingle = false;
  bool _singleMatched = false;

  // Multi-dependency path keeps a stable subscription set and last read order.
  Set<LevitReactiveNotifier>? _notifiers;
  List<LevitReactiveNotifier>? _orderedNotifiers;
  Map<(Type, String, String), LxReactive?>? _logicalReactiveIndex;
  bool _expectingOrdered = false;
  int _matchedCount = 0;

  // Reusable capture storage used only when dependencies change.
  List<LevitReactiveNotifier>? _newNotifiers;
  Set<LevitReactiveNotifier>? _scratchNotifiers;
  LxListenerContext? _cachedContext;
  LevitScope? _cachedScope;
  bool _scopeResolved = false;
  late final VoidCallback _triggerRebuildCallback = _triggerRebuild;

  LevitScope? _resolveNearestScope() {
    if (!_scopeResolved) {
      _cachedScope = _ScopeProvider.of(this, listen: true);
      _scopeResolved = true;
    }
    return _cachedScope;
  }

  @override
  void didChangeDependencies() {
    _scopeResolved = false;
    super.didChangeDependencies();
  }

  @override
  void activate() {
    _scopeResolved = false;
    super.activate();
  }

  @override
  void addNotifier(LevitReactiveNotifier notifier) {
    if (_expectingSingle) {
      if (identical(_singleNotifier, notifier)) {
        _singleMatched = true;
        return;
      }
      _expectingSingle = false;
      final captured = _newNotifiers ??= [];
      if (_singleMatched) {
        captured.add(_singleNotifier!);
      }
      captured.add(notifier);
      return;
    }

    if (_expectingOrdered) {
      final expected = _orderedNotifiers!;
      if (_matchedCount < expected.length &&
          identical(expected[_matchedCount], notifier)) {
        _matchedCount++;
        return;
      }
      for (var i = 0; i < _matchedCount; i++) {
        if (identical(expected[i], notifier)) return;
      }
      _expectingOrdered = false;
      final captured = _newNotifiers ??= [];
      for (var i = 0; i < _matchedCount; i++) {
        captured.add(expected[i]);
      }
      captured.add(notifier);
      return;
    }

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
    if (_usingSinglePath && single != null) {
      if (identical(single, reactive)) return reactive;
      if (!single.isDisposed && single is LxReactive) {
        final stable = single as LxReactive;
        if (_isSameLogicalReactive(stable, reactive)) {
          return stable;
        }
      }
      return reactive;
    }

    final nots = _notifiers;
    if (nots == null || nots.isEmpty) return reactive;
    if (reactive case final LevitReactiveNotifier notifier
        when nots.contains(notifier)) {
      return reactive;
    }

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
      _singleNotifier?.removeListener(_triggerRebuildCallback);
      _singleNotifier = null;
      _usingSinglePath = false;
    }

    final nots = _notifiers;
    if (nots != null && nots.isNotEmpty) {
      for (final n in nots) {
        n.removeListener(_triggerRebuildCallback);
      }
      nots.clear();
    }
    _orderedNotifiers = null;
    _logicalReactiveIndex = null;
  }

  void _triggerRebuild() {
    if (mounted) {
      markNeedsBuild();
    }
  }

  void _addNotifierListener(LevitReactiveNotifier notifier) {
    if (LxSpi.hasListenerMiddlewares) {
      LxSpi.runWithContext(_buildContext(), () {
        notifier.addListener(_triggerRebuildCallback);
      });
    } else {
      notifier.addListener(_triggerRebuildCallback);
    }
  }

  void _removeNotifierListener(LevitReactiveNotifier notifier) {
    if (LxSpi.hasListenerMiddlewares) {
      LxSpi.runWithContext(_buildContext(), () {
        notifier.removeListener(_triggerRebuildCallback);
      });
    } else {
      notifier.removeListener(_triggerRebuildCallback);
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

    _newNotifiers?.clear();
    _expectingSingle = _usingSinglePath;
    _singleMatched = false;
    _expectingOrdered = !_usingSinglePath && _orderedNotifiers != null;
    _matchedCount = 0;

    final previousProxy = LxSpi.proxy;
    if (identical(previousProxy, this)) {
      // Force-reset read dedupe cache for a fresh dependency capture cycle.
      LxSpi.proxy = null;
    }
    LxSpi.proxy = this;

    final Widget result;
    final builder = (widget as LWatch).builder;
    final scope = _resolveNearestScope();
    try {
      if (scope == null || identical(scope, Ls.currentScope)) {
        result = builder();
      } else {
        final previousScope = LsSpi.enterSyncScope(scope);
        try {
          result = builder();
        } finally {
          LsSpi.exitSyncScope(previousScope);
        }
      }
    } finally {
      LxSpi.proxy = previousProxy;
    }

    if (_expectingSingle && _singleMatched) {
      return result;
    }
    if (_expectingOrdered) {
      final expected = _orderedNotifiers!;
      if (_matchedCount == expected.length) {
        return result;
      }
      final captured = _newNotifiers ??= [];
      for (var i = 0; i < _matchedCount; i++) {
        captured.add(expected[i]);
      }
    }

    _updateSubscriptions(_newNotifiers);

    return result;
  }

  void _updateSubscriptions(List<LevitReactiveNotifier>? nextNotifiers) {
    // No dependencies means the watch should hold no subscriptions.
    if (nextNotifiers == null || nextNotifiers.isEmpty) {
      if (_usingSinglePath || (_notifiers?.isNotEmpty ?? false)) {
        _runCleanupAll();
      }
      return;
    }

    // Single dependency can be swapped with constant-time checks.
    if (nextNotifiers.length == 1) {
      final notifier = nextNotifiers[0];
      _cleanupAll();
      _singleNotifier = notifier;
      _usingSinglePath = true;
      _addNotifierListener(notifier);
      return;
    }

    // Multi-dependency reconciliation path.
    if (_usingSinglePath) {
      _singleNotifier?.removeListener(_triggerRebuildCallback);
      _singleNotifier = null;
      _usingSinglePath = false;
    }

    // Scratch set enables dedupe without allocating a new set each build.
    final targetNots = _notifiers ??= Set<LevitReactiveNotifier>.identity();
    final scratch = _scratchNotifiers ??= Set<LevitReactiveNotifier>.identity();
    scratch.clear();
    final ordered = <LevitReactiveNotifier>[];

    // Subscribe new dependencies and keep existing ones.
    for (final n in nextNotifiers) {
      if (!scratch.add(n)) continue;
      ordered.add(n);
      if (targetNots.add(n)) {
        _addNotifierListener(n);
      }
    }

    // Unsubscribe dependencies no longer observed by the builder.
    if (targetNots.length != scratch.length) {
      targetNots.removeWhere((notifier) {
        if (scratch.contains(notifier)) return false;
        _removeNotifierListener(notifier);
        return true;
      });
    }

    _orderedNotifiers = ordered;
    _rebuildLogicalReactiveIndex(targetNots);
  }

  void _runCleanupAll() {
    if (LxSpi.hasListenerMiddlewares) {
      LxSpi.runWithContext(_buildContext(), _cleanupAll);
    } else {
      _cleanupAll();
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
    _cachedScope = null;
    _scopeResolved = false;
    _runCleanupAll();
    super.unmount();
  }
}
