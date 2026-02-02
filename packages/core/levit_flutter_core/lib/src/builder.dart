part of '../levit_flutter_core.dart';

/// A widget that explicitly observes a single [LxReactive] value.
///
/// Use [LBuilder] when you want to be explicit about the dependency, or when
/// avoiding the overhead of proxy-tracking in [LWatch].
///
/// Example:
/// ```dart
/// LBuilder(counter, (value) {
///   return Text('Count: $value');
/// });
/// ```
class LBuilder<T> extends Widget {
  /// The builder function used to generate the widget tree.
  final Widget Function(T x) builder;

  /// The reactive object to observe.
  final LxReactive<T> x;

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
    runWithContext(() {
      (widget as LBuilder<T>).x.addListener(onNotify);
    });
  }

  @override
  void update(LBuilder<T> newWidget) {
    final oldWidget = widget as LBuilder<T>;
    super.update(newWidget);
    if (newWidget.x != oldWidget.x) {
      runWithContext(() {
        oldWidget.x.removeListener(onNotify);
        newWidget.x.addListener(onNotify);
      });
    }
    markNeedsBuild(); // Force rebuild
    rebuild();
  }

  @override
  Widget build() {
    return (widget as LBuilder<T>).builder((widget as LBuilder<T>).x.value);
  }

  @override
  void unmount() {
    runWithContext(() {
      (widget as LBuilder<T>).x.removeListener(onNotify);
    });
    super.unmount();
  }
}

/// A widget that manages a local [LxComputed].
///
/// Useful for observing a derived value that is only needed for this specific
/// widget subtree. The computed value is automatically disposed when the
/// widget is unmounted.
///
/// Example:
/// ```dart
/// LSelectorBuilder(
///   () => user.firstName() + user.lastName(),
///   (fullName) => Text('Hello $fullName'),
/// );
/// ```
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

  late LxComputed<T> _computed;

  @override
  void mount(Element? parent, Object? newSlot) {
    _initComputed();
    super.mount(parent, newSlot);
  }

  void _initComputed() {
    _computed = LxComputed((widget as LSelectorBuilder<T>).valueBuilder);
    _listen();
  }

  void _listen() {
    runWithContext(() {
      _computed.addListener(onNotify);
    });
  }

  @override
  void update(LSelectorBuilder<T> newWidget) {
    final oldWidget = widget as LSelectorBuilder<T>;
    super.update(newWidget);

    if (newWidget.valueBuilder != oldWidget.valueBuilder) {
      runWithContext(() {
        _computed.removeListener(onNotify);
      });
      _computed.dispose();
      _initComputed();
    }

    markNeedsBuild();
  }

  @override
  Widget build() {
    return (widget as LSelectorBuilder<T>).builder(_computed.value);
  }

  @override
  void unmount() {
    runWithContext(() {
      _computed.removeListener(onNotify);
    });
    _computed.dispose();
    super.unmount();
  }
}

/// A widget specialized for handling [LxStatus].
///
/// Eliminates boilerplate when handling loading, error, and success states
/// of an asynchronous reactive value.
///
/// Example:
/// ```dart
/// LStatusBuilder(
///   userStatus,
///   onSuccess: (user) => UserProfile(user),
///   onWaiting: () => const LoadingSpinner(),
///   onError: (e, s) => ErrorView(e),
/// );
/// ```
class LStatusBuilder<T> extends Widget {
  /// The reactive status to observe.
  final LxReactive<LxStatus<T>> x;

  /// Called when the status is [LxSuccess].
  final Widget Function(T data) onSuccess;

  /// Called when simple waiting logic is needed.
  final Widget Function()? onWaiting;

  /// Called when the status is [LxError].
  final Widget Function(Object error, StackTrace? stackTrace)? onError;

  /// Called when the status is [LxIdle].
  final Widget Function()? onIdle;

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
    runWithContext(() {
      (widget as LStatusBuilder<T>).x.addListener(onNotify);
    });
  }

  @override
  void update(LStatusBuilder<T> newWidget) {
    final oldWidget = widget as LStatusBuilder<T>;
    super.update(newWidget);
    if (newWidget.x != oldWidget.x) {
      runWithContext(() {
        oldWidget.x.removeListener(onNotify);
        newWidget.x.addListener(onNotify);
      });
    }
    markNeedsBuild();
    rebuild();
  }

  @override
  Widget build() {
    final w = widget as LStatusBuilder<T>;
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
    runWithContext(() {
      (widget as LStatusBuilder<T>).x.removeListener(onNotify);
    });
    super.unmount();
  }
}

mixin _LReactiveElementMixin<W extends Widget> on ComponentElement {
  LxListenerContext? _cachedContext;

  void onNotify() {
    if (mounted) markNeedsBuild();
  }

  void runWithContext(void Function() fn) {
    if (LevitReactiveMiddleware.hasListenerMiddlewares) {
      Lx.runWithContext(_buildContext(), fn);
    } else {
      fn();
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
