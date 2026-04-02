part of '../levit_flutter_core.dart';

/// Visibility state for the route bound to an [LRouteScope].
enum LRouteVisibility {
  /// No active route is currently bound to the scope.
  inactive,

  /// The bound route is the current visible route.
  current,

  /// The bound route is still active but currently covered by another route.
  covered,
}

class _RouteScopeProvider extends InheritedWidget {
  final ModalRoute<dynamic>? route;
  final LxReactive<LRouteVisibility> visibility;

  const _RouteScopeProvider({
    required this.route,
    required this.visibility,
    required super.child,
  });

  static _RouteScopeProvider? of(BuildContext context, {bool listen = false}) {
    return listen
        ? context.dependOnInheritedWidgetOfExactType<_RouteScopeProvider>()
        : context.getInheritedWidgetOfExactType<_RouteScopeProvider>();
  }

  @override
  bool updateShouldNotify(_RouteScopeProvider oldWidget) =>
      route != oldWidget.route || !identical(visibility, oldWidget.visibility);
}

class _RouteBinding extends StatefulWidget {
  final List<Object?>? args;
  final Widget Function(
    BuildContext context,
    ModalRoute<dynamic>? route,
    LxReactive<LRouteVisibility> visibility,
    List<Object?> scopeArgs,
  ) builder;

  const _RouteBinding({
    this.args,
    required this.builder,
  });

  @override
  State<_RouteBinding> createState() => _RouteBindingState();
}

class _RouteBindingState extends State<_RouteBinding> {
  final LxVar<LRouteVisibility> _visibility =
      LxVar(LRouteVisibility.inactive).named('routeVisibility');
  ModalRoute<dynamic>? _route;
  Animation<double>? _routeAnimation;
  Animation<double>? _secondaryAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!identical(_route, route)) {
      _unsubscribeFromRoute();
      _route = route;
      _subscribeToRoute();
    }
    _syncVisibility();
  }

  void _subscribeToRoute() {
    final route = _route;
    final animation = route?.animation;
    if (animation != null) {
      _routeAnimation = animation;
      animation.addListener(_syncVisibility);
      animation.addStatusListener(_onAnimationStatusChanged);
    }

    final secondary = route?.secondaryAnimation;
    if (secondary != null && !identical(secondary, animation)) {
      _secondaryAnimation = secondary;
      secondary.addListener(_syncVisibility);
      secondary.addStatusListener(_onAnimationStatusChanged);
    }
  }

  void _unsubscribeFromRoute() {
    final animation = _routeAnimation;
    if (animation != null) {
      animation.removeListener(_syncVisibility);
      animation.removeStatusListener(_onAnimationStatusChanged);
      _routeAnimation = null;
    }

    final secondary = _secondaryAnimation;
    if (secondary != null) {
      secondary.removeListener(_syncVisibility);
      secondary.removeStatusListener(_onAnimationStatusChanged);
      _secondaryAnimation = null;
    }
  }

  void _onAnimationStatusChanged(AnimationStatus _) {
    _syncVisibility();
  }

  void _syncVisibility() {
    final next = switch (_route) {
      null => LRouteVisibility.inactive,
      final route when !route.isActive => LRouteVisibility.inactive,
      final route when route.isCurrent => LRouteVisibility.current,
      _ => LRouteVisibility.covered,
    };

    if (_visibility.value != next) {
      _visibility.value = next;
    }
  }

  @override
  void dispose() {
    _unsubscribeFromRoute();
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final scopeArgs = <Object?>[
      ...?widget.args,
      route,
    ];

    return _RouteScopeProvider(
      route: route,
      visibility: _visibility,
      child: widget.builder(
        context,
        route,
        _visibility,
        scopeArgs,
      ),
    );
  }
}

/// A route-aware wrapper around [LScope].
///
/// `LRouteScope` keeps the underlying dependency scope widget-tree-bound, but
/// also binds that scope to the current [ModalRoute]. When the route identity
/// changes, the local scope is recreated. Descendants can observe the current
/// route visibility through [visibilityOf].
///
/// This is useful when route lifetime, not just subtree lifetime, is the
/// meaningful ownership boundary.
class LRouteScope extends StatelessWidget {
  /// An optional factory to register dependencies in this scope.
  final LScopeDependencyFactory? dependencyFactory;

  /// The widget subtree that will have access to this scope.
  final Widget child;

  /// A descriptive name for the scope.
  final String? name;

  /// Optional dependency keys for reactive re-initialization.
  ///
  /// The bound [ModalRoute] is always appended internally so the scope resets
  /// when route identity changes.
  final List<Object?>? args;

  /// Creates a route-bound dependency scope.
  const LRouteScope({
    super.key,
    this.dependencyFactory,
    required this.child,
    this.name,
    this.args,
  });

  /// A shorthand for creating a route-bound scope and immediately registering
  /// a dependency.
  static LRouteScope put<S>(
    S Function() builder, {
    Key? key,
    required Widget child,
    String? name,
    String? tag,
    bool permanent = false,
    List<Object?>? args,
  }) {
    return LRouteScope(
      key: key,
      name: name,
      args: args,
      dependencyFactory: (s) {
        s.put<S>(builder, tag: tag, permanent: permanent);
      },
      child: child,
    );
  }

  /// A shorthand for creating a route-bound scope and registering a lazy
  /// dependency.
  static LRouteScope lazyPut<S>(
    S Function() builder, {
    Key? key,
    required Widget child,
    String? name,
    String? tag,
    bool permanent = false,
    bool isFactory = false,
    List<Object?>? args,
  }) {
    return LRouteScope(
      key: key,
      name: name,
      args: args,
      dependencyFactory: (s) {
        s.lazyPut<S>(
          builder,
          tag: tag,
          permanent: permanent,
          isFactory: isFactory,
        );
      },
      child: child,
    );
  }

  /// A shorthand for creating a route-bound scope and registering an async
  /// lazy dependency.
  static LRouteScope lazyPutAsync<S>(
    Future<S> Function() builder, {
    Key? key,
    required Widget child,
    String? name,
    String? tag,
    bool permanent = false,
    bool isFactory = false,
    List<Object?>? args,
  }) {
    return LRouteScope(
      key: key,
      name: name,
      args: args,
      dependencyFactory: (s) {
        s.lazyPutAsync<S>(
          builder,
          tag: tag,
          permanent: permanent,
          isFactory: isFactory,
        );
      },
      child: child,
    );
  }

  /// The [ModalRoute] currently bound to the nearest [LRouteScope].
  static ModalRoute<dynamic>? routeOf(BuildContext context,
          {bool listen = false}) =>
      _RouteScopeProvider.of(context, listen: listen)?.route;

  /// Reactive visibility for the nearest [LRouteScope].
  ///
  /// Observe this with [LBuilder] or [LWatch] when route coverage matters.
  static LxReactive<LRouteVisibility>? visibilityOf(BuildContext context,
          {bool listen = false}) =>
      _RouteScopeProvider.of(context, listen: listen)?.visibility;

  /// Snapshot visibility for the nearest [LRouteScope].
  static LRouteVisibility visibilityValueOf(BuildContext context,
          {bool listen = false}) =>
      visibilityOf(context, listen: listen)?.value ?? LRouteVisibility.inactive;

  @override
  Widget build(BuildContext context) {
    return _RouteBinding(
      args: args,
      builder: (context, route, visibility, scopeArgs) {
        return LScope(
          name: name ?? route?.settings.name ?? 'LRouteScope',
          args: scopeArgs,
          dependencyFactory: dependencyFactory,
          child: child,
        );
      },
    );
  }
}

/// An async route-aware wrapper around [LAsyncScope].
///
/// `LAsyncRouteScope` keeps async dependency initialization widget-tree-bound,
/// but resets that local scope when the current [ModalRoute] identity changes.
/// Descendants can observe the current route visibility through [visibilityOf].
class LAsyncRouteScope extends StatelessWidget {
  /// An async factory to register dependencies.
  final LAsyncScopeDependencyFactory dependencyFactory;

  /// The widget subtree to render after initialization.
  final Widget child;

  /// A descriptive name for the scope.
  final String? name;

  /// Optional builder for the loading state.
  final Widget Function(BuildContext context)? loading;

  /// Optional builder for the error state.
  final Widget Function(BuildContext context, Object error)? error;

  /// Optional dependency keys for reactive re-initialization.
  ///
  /// The bound [ModalRoute] is always appended internally so the scope resets
  /// when route identity changes.
  final List<Object?>? args;

  const LAsyncRouteScope({
    super.key,
    required this.dependencyFactory,
    required this.child,
    this.name,
    this.loading,
    this.error,
    this.args,
  });

  /// The [ModalRoute] currently bound to the nearest [LAsyncRouteScope] or
  /// [LRouteScope].
  static ModalRoute<dynamic>? routeOf(BuildContext context,
          {bool listen = false}) =>
      LRouteScope.routeOf(context, listen: listen);

  /// Reactive visibility for the nearest [LAsyncRouteScope] or [LRouteScope].
  static LxReactive<LRouteVisibility>? visibilityOf(BuildContext context,
          {bool listen = false}) =>
      LRouteScope.visibilityOf(context, listen: listen);

  /// Snapshot visibility for the nearest [LAsyncRouteScope] or [LRouteScope].
  static LRouteVisibility visibilityValueOf(BuildContext context,
          {bool listen = false}) =>
      LRouteScope.visibilityValueOf(context, listen: listen);

  @override
  Widget build(BuildContext context) {
    return _RouteBinding(
      args: args,
      builder: (context, route, visibility, scopeArgs) {
        return LAsyncScope(
          name: name ?? route?.settings.name ?? 'LAsyncRouteScope',
          args: scopeArgs,
          dependencyFactory: dependencyFactory,
          loading: loading,
          error: error,
          child: child,
        );
      },
    );
  }
}
