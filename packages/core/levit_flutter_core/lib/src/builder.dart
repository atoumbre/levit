part of '../levit_flutter_core.dart';

/// A widget that explicitly observes a single [LxReadable] value.
///
/// Use [LBuilder] when you want to be explicit about the dependency, or when
/// avoiding the overhead of proxy-tracking in [LWatch].
///
/// ```dart
/// LBuilder(counter, (value) {
///   return Text('Count: $value');
/// });
/// ```
///
/// {@category Flutter Widgets & Interop}
class LBuilder<T> extends Widget {
  /// The builder function used to generate the widget tree.
  final Widget Function(T x) builder;

  /// The reactive object to observe.
  final LxReadable<T> x;

  /// Creates an explicit reactive builder.
  const LBuilder(this.x, this.builder, {super.key});

  @override
  Element createElement() => _LBuilderElement<T>(this);
}

class _LBuilderElement<T> extends ComponentElement
    with _LReactiveElementMixin<LBuilder<T>> {
  _LBuilderElement(super.widget);

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _attachListener((widget as LBuilder<T>).x);
  }

  @override
  void update(LBuilder<T> newWidget) {
    final oldWidget = widget as LBuilder<T>;
    super.update(newWidget);
    if (newWidget.x != oldWidget.x) {
      _swapListener(oldWidget.x, newWidget.x);
    }
    rebuild(force: true);
  }

  @override
  Widget build() {
    final w = widget as LBuilder<T>;
    final scope = _resolveNearestScope();
    if (scope == null || identical(scope, Ls.currentScope)) {
      return w.builder(w.x.value);
    }
    final previous = LsSpi.enterSyncScope(scope);
    try {
      return w.builder(w.x.value);
    } finally {
      LsSpi.exitSyncScope(previous);
    }
  }

  @override
  void unmount() {
    _detachListener((widget as LBuilder<T>).x);
    super.unmount();
  }
}

/// A widget that manages a local [LxComputed] and rebuilds only when its
/// derived value changes according to `==`.
///
/// Useful for observing a derived value that is only needed for this specific
/// widget subtree. The computed value is automatically disposed when the
/// widget is unmounted and refreshed in place if [valueBuilder] changes
/// identity.
///
/// ```dart
/// LSelectorBuilder(
///   () => '${user.firstName()} ${user.lastName()}',
///   (fullName) => Text('Hello $fullName'),
/// );
/// ```
///
/// {@category Flutter Widgets & Interop}
class LSelectorBuilder<T> extends Widget {
  /// The function that computes the value to observe.
  final T Function() valueBuilder;

  /// The widget builder.
  final Widget Function(T value) builder;

  /// Creates a widget with a locally-managed computed value.
  const LSelectorBuilder(this.valueBuilder, this.builder, {super.key});

  @override
  Element createElement() => _LSelectBuilderElement<T>(this);
}

class _LSelectBuilderElement<T> extends ComponentElement
    with _LReactiveElementMixin<LSelectorBuilder<T>> {
  _LSelectBuilderElement(super.widget);

  late final LxComputed<T> _computed = LxComputed<T>(
    () => (widget as LSelectorBuilder<T>).valueBuilder(),
    eager: true,
  );
  bool _isUpdating = false;

  @override
  void onNotify() {
    if (!_isUpdating && mounted) markNeedsBuild();
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    _attachListener(_computed);
    super.mount(parent, newSlot);
  }

  @override
  void update(LSelectorBuilder<T> newWidget) {
    final oldWidget = widget as LSelectorBuilder<T>;
    super.update(newWidget);

    if (newWidget.valueBuilder != oldWidget.valueBuilder) {
      _isUpdating = true;
      try {
        _computed.refresh();
      } finally {
        _isUpdating = false;
      }
    }

    rebuild(force: true);
  }

  @override
  Widget build() {
    final w = widget as LSelectorBuilder<T>;
    final scope = _resolveNearestScope();
    if (scope == null || identical(scope, Ls.currentScope)) {
      return w.builder(_computed.value);
    }
    final previous = LsSpi.enterSyncScope(scope);
    try {
      return w.builder(_computed.value);
    } finally {
      LsSpi.exitSyncScope(previous);
    }
  }

  @override
  void unmount() {
    _detachListener(_computed);
    _computed.dispose();
    super.unmount();
  }
}

/// A widget specialized for handling [LxStatus].
///
/// Eliminates boilerplate when handling loading, error, and success states
/// of an asynchronous reactive value.
///
/// ```dart
/// LStatusBuilder(
///   userStatus,
///   onSuccess: (user) => UserProfile(user),
///   onWaiting: (status) => const LoadingSpinner(),
///   onError: (status) => ErrorView(status.error),
/// );
/// ```
///
/// {@category Flutter Widgets & Interop}
class LStatusBuilder<T> extends Widget {
  /// The reactive status to observe.
  final LxReadable<LxStatus<T>> x;

  /// Called when the status is [LxSuccess].
  final Widget Function(T data) onSuccess;

  /// Called when the status is [LxWaiting], and used as a fallback for
  /// [LxIdle] when [onIdle] is `null`. Defaults to `SizedBox.shrink()`.
  final Widget Function(LxWaiting<T> status)? onWaiting;

  /// Called when the status is [LxError]. Defaults to
  /// `Center(child: Text('Error: ${status.error}'))`.
  final Widget Function(LxError<T> status)? onError;

  /// Called when the status is [LxIdle]. Falls back to [onWaiting] (with a
  /// waiting view retaining any previous value) or `SizedBox.shrink()`.
  final Widget Function(LxIdle<T> status)? onIdle;

  /// Creates a status-aware builder.
  const LStatusBuilder(
    this.x, {
    super.key,
    required this.onSuccess,
    this.onWaiting,
    this.onError,
    this.onIdle,
  });

  @override
  Element createElement() => _LStatusBuilderElement<T>(this);
}

class _LStatusBuilderElement<T> extends ComponentElement
    with _LReactiveElementMixin<LStatusBuilder<T>> {
  _LStatusBuilderElement(super.widget);

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _attachListener((widget as LStatusBuilder<T>).x);
  }

  @override
  void update(LStatusBuilder<T> newWidget) {
    final oldWidget = widget as LStatusBuilder<T>;
    super.update(newWidget);
    if (newWidget.x != oldWidget.x) {
      _swapListener(oldWidget.x, newWidget.x);
    }
    rebuild(force: true);
  }

  @override
  Widget build() {
    final w = widget as LStatusBuilder<T>;
    final scope = _resolveNearestScope();
    if (scope == null || identical(scope, Ls.currentScope)) {
      return _buildStatus(w);
    }
    final previous = LsSpi.enterSyncScope(scope);
    try {
      return _buildStatus(w);
    } finally {
      LsSpi.exitSyncScope(previous);
    }
  }

  Widget _buildStatus(LStatusBuilder<T> w) {
    final status = w.x.value;
    return switch (status) {
      LxIdle<T>() =>
        w.onIdle?.call(status) ??
            w.onWaiting?.call(LxWaiting<T>.fromPrevious(status)) ??
            const SizedBox.shrink(),
      LxWaiting<T>() => w.onWaiting?.call(status) ?? const SizedBox.shrink(),
      LxError<T>(:final error) =>
        w.onError?.call(status) ?? Center(child: Text('Error: $error')),
      LxSuccess<T>(:final value) => w.onSuccess(value),
    };
  }

  @override
  void unmount() {
    _detachListener((widget as LStatusBuilder<T>).x);
    super.unmount();
  }
}

mixin _LReactiveElementMixin<W extends Widget> on ComponentElement {
  LxListenerContext? _cachedContext;
  LevitScope? _cachedScope;
  bool _scopeResolved = false;
  late final VoidCallback _onNotifyCallback = onNotify;

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
  void unmount() {
    _cachedScope = null;
    _scopeResolved = false;
    super.unmount();
  }

  void onNotify() {
    if (mounted) markNeedsBuild();
  }

  void _attachListener(LxReadable<dynamic> reactive) {
    if (LxSpi.hasListenerMiddlewares) {
      LxSpi.runWithContext(_buildContext(), () {
        reactive.addListener(_onNotifyCallback);
      });
    } else {
      reactive.addListener(_onNotifyCallback);
    }
  }

  void _detachListener(LxReadable<dynamic> reactive) {
    if (LxSpi.hasListenerMiddlewares) {
      LxSpi.runWithContext(_buildContext(), () {
        reactive.removeListener(_onNotifyCallback);
      });
    } else {
      reactive.removeListener(_onNotifyCallback);
    }
  }

  void _swapListener(
    LxReadable<dynamic> oldReactive,
    LxReadable<dynamic> newReactive,
  ) {
    if (LxSpi.hasListenerMiddlewares) {
      LxSpi.runWithContext(_buildContext(), () {
        oldReactive.removeListener(_onNotifyCallback);
        newReactive.addListener(_onNotifyCallback);
      });
    } else {
      oldReactive.removeListener(_onNotifyCallback);
      newReactive.addListener(_onNotifyCallback);
    }
  }

  LxListenerContext _buildContext() {
    return _cachedContext ??= LxListenerContext(
      type: widget.runtimeType.toString(),
      id: identityHashCode(this),
      data: {'runtimeType': widget.runtimeType.toString()},
    );
  }
}
