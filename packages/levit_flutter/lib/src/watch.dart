import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:levit_dart/levit_dart.dart';

/// A reactive widget that automatically rebuilds when accessed [Lx] values change.
class LWatch extends Widget {
  /// The builder function that constructs the widget tree.
  final Widget Function() builder;

  /// An optional label for debugging purposes.
  final String? debugLabel;

  /// Creates a reactive [LWatch] widget.
  const LWatch(this.builder, {super.key, this.debugLabel});

  @override
  Element createElement() => LWatchElement(this);
}

class LWatchElement extends ComponentElement implements LevitStateObserver {
  LWatchElement(LWatch super.widget);

  @override
  void update(LWatch newWidget) {
    super.update(newWidget);
    markNeedsBuild(); // Force rebuild on update
    rebuild();
  }

  // ===== Fast path for single notifier (most common case) =====
  LevitStateNotifier? _singleNotifier;
  bool _usingSinglePath = false;

  // ===== Slow path for multiple dependencies =====
  Map<Stream, StreamSubscription>? _subscriptions;
  Map<LevitStateNotifier, void Function()>? _notifiers;

  // Optimized: Use List instead of Set for zero-allocation capture
  List<Stream>? _newStreams;
  List<LevitStateNotifier>? _newNotifiers;

  bool _isDirty = false;

  @override
  void addStream<T>(Stream<T> stream) {
    (_newStreams ??= []).add(stream);
  }

  @override
  void addNotifier(LevitStateNotifier notifier) {
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

    final subs = _subscriptions;
    if (subs != null && subs.isNotEmpty) {
      for (final sub in subs.values) {
        sub.cancel();
      }
      subs.clear();
    }

    final nots = _notifiers;
    if (nots != null && nots.isNotEmpty) {
      for (final entry in nots.entries) {
        entry.key.removeListener(entry.value);
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
    _newStreams = null;
    _newNotifiers = null;

    final previousProxy = Lx.proxy;
    Lx.proxy = this;

    final Widget result;
    try {
      result = (widget as LWatch).builder();
    } finally {
      Lx.proxy = previousProxy;
    }

    _updateSubscriptions(_newStreams, _newNotifiers);

    return result;
  }

  void _updateSubscriptions(
      List<Stream>? nextStreams, List<LevitStateNotifier>? nextNotifiers) {
    // 1. FAST PATH: Single Notifier, No Streams
    if (nextStreams == null &&
        nextNotifiers != null &&
        nextNotifiers.length == 1) {
      final notifier = nextNotifiers[0];
      if (_usingSinglePath && identical(_singleNotifier, notifier)) {
        return; // Exact match, zero work
      }

      _cleanupAll();
      _singleNotifier = notifier;
      _usingSinglePath = true;
      notifier.addListener(_triggerRebuild);
      return;
    }

    // 2. EMPTY PATH: No dependencies
    if (nextStreams == null && nextNotifiers == null) {
      if (_usingSinglePath ||
          (_subscriptions?.isNotEmpty ?? false) ||
          (_notifiers?.isNotEmpty ?? false)) {
        _cleanupAll();
      }
      return;
    }

    // 3. SLOW PATH: Multiple Notifiers or Streams
    // Clean up fast path if used
    if (_usingSinglePath) {
      _singleNotifier?.removeListener(_triggerRebuild);
      _singleNotifier = null;
      _usingSinglePath = false;
    }

    // Process Streams
    final currentSubs = _subscriptions;
    if (nextStreams != null) {
      final targetSubs = _subscriptions ??= {};
      // Add new
      for (var i = 0; i < nextStreams.length; i++) {
        final s = nextStreams[i];
        if (!targetSubs.containsKey(s)) {
          targetSubs[s] = s.listen((_) => _triggerRebuild());
        }
      }
      // Remove old (only if we have existing subs)
      if (currentSubs != null && currentSubs.isNotEmpty) {
        // Avoid toSet() allocation - use list containment check
        currentSubs.removeWhere((stream, sub) {
          for (var i = 0; i < nextStreams.length; i++) {
            if (identical(stream, nextStreams[i])) return false;
          }
          sub.cancel();
          return true;
        });
      }
    } else if (currentSubs != null && currentSubs.isNotEmpty) {
      // Clear all streams if none new
      for (final sub in currentSubs.values) {
        sub.cancel();
      }
      currentSubs.clear();
    }

    // Process Notifiers
    final currentNots = _notifiers;
    if (nextNotifiers != null) {
      final targetNots = _notifiers ??= {};
      // Add new
      for (var i = 0; i < nextNotifiers.length; i++) {
        final n = nextNotifiers[i];
        if (!targetNots.containsKey(n)) {
          targetNots[n] = _triggerRebuild;
          n.addListener(_triggerRebuild);
        }
      }
      // Remove old - avoid toSet() allocation
      if (currentNots != null && currentNots.isNotEmpty) {
        currentNots.removeWhere((notifier, listener) {
          for (var i = 0; i < nextNotifiers.length; i++) {
            if (identical(notifier, nextNotifiers[i])) return false;
          }
          notifier.removeListener(listener);
          return true;
        });
      }
    } else if (currentNots != null && currentNots.isNotEmpty) {
      // Clear all notifiers if none new
      for (final entry in currentNots.entries) {
        entry.key.removeListener(entry.value);
      }
      currentNots.clear();
    }
  }

  @override
  void unmount() {
    _cleanupAll();
    super.unmount();
  }
}

/// A reactive widget that observes a single specific reactive value.
///
/// Unlike [LWatch], which tracks dependencies automatically, [LValue]
/// requires you to explicitly provide the reactive variable [LxVal]. This avoids
/// the overhead of the proxy mechanism and can be slightly more performant
/// for simple use cases.
class LValue<T extends LxReactive> extends Widget {
  /// The builder function that receives the reactive value.
  final Widget Function(T value) builder;

  /// The reactive value to observe.
  final T x;

  /// Creates a widget that watches the specific reactive object [x].
  const LValue(this.x, this.builder, {super.key});

  @override
  Element createElement() => LValueElement<T>(this);
}

class LValueElement<T extends LxReactive> extends ComponentElement {
  LValueElement(LValue<T> super.widget);

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    (widget as LValue<T>).x.addListener(_onNotify);
  }

  void _onNotify() {
    if (mounted) markNeedsBuild();
  }

  @override
  void update(LValue<T> newWidget) {
    final oldWidget = widget as LValue<T>;
    super.update(newWidget);
    if (newWidget.x != oldWidget.x) {
      oldWidget.x.removeListener(_onNotify);
      newWidget.x.addListener(_onNotify);
    }
    markNeedsBuild(); // Force rebuild
    rebuild();
  }

  @override
  Widget build() {
    return (widget as LValue<T>).builder((widget as LValue<T>).x);
  }

  @override
  void unmount() {
    (widget as LValue<T>).x.removeListener(_onNotify);
    super.unmount();
  }
}
