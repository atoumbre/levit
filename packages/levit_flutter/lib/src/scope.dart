import 'package:flutter/widgets.dart';
import 'package:levit_dart/levit_dart.dart';
import 'package:levit_flutter/src/watch.dart';

/// An internal widget that propagates the [LevitScope] down the widget tree.
class _ScopeProvider extends InheritedWidget {
  final LevitScope scope;

  const _ScopeProvider({
    required this.scope,
    required super.child,
  });

  static LevitScope? of(BuildContext context) {
    // We use getInheritedWidgetOfExactType instead of dependOnInheritedWidgetOfExactType
    // because the scope itself doesn't change after creation, and we don't want
    // rebuilds just because we accessed the scope.
    return context.getInheritedWidgetOfExactType<_ScopeProvider>()?.scope;
  }

  @override
  bool updateShouldNotify(_ScopeProvider oldWidget) => scope != oldWidget.scope;
}

// Logic to create a scope from context
LevitScope _createChildScope(BuildContext context, String scopeName) {
  final parentScope = _ScopeProvider.of(context);
  if (parentScope != null) {
    return parentScope.createScope(scopeName);
  }
  return Levit.createScope(scopeName);
}

/// A widget that creates and manages a dependency injection scope.
class LScope<T> extends Widget {
  final T Function() init;
  final Widget child;
  final String? tag;
  final bool permanent;
  final String? name;

  const LScope({
    super.key,
    required this.init,
    required this.child,
    this.tag,
    this.permanent = false,
    this.name,
  });

  @override
  Element createElement() => LScopeElement<T>(this);

  /// Retrieves the nearest [LevitScope] from the widget tree.
  static LevitScope? of(BuildContext context) => _ScopeProvider.of(context);
}

class LScopeElement<T> extends ComponentElement {
  LScopeElement(LScope<T> super.widget);

  late LevitScope _scope;
  bool _scopeInitialized = false;

  void _initScope() {
    if (_scopeInitialized) return;
    final widget = this.widget as LScope<T>;
    final scopeName = widget.name ?? 'LScope<${T.toString()}>';
    _scope = _createChildScope(this, scopeName);
    _scope.put<T>(widget.init, tag: widget.tag, permanent: widget.permanent);
    _scopeInitialized = true;
  }

  @override
  void update(LScope<T> newWidget) {
    final oldWidget = widget as LScope<T>;
    super.update(newWidget);
    if (newWidget.tag != oldWidget.tag || newWidget.name != oldWidget.name) {
      assert(() {
        debugPrint(
            'WARNING: LScope tag/name changed but scope cannot be updated dynamically.');
        return true;
      }());
    }
    markNeedsBuild();
    rebuild();
  }

  @override
  Widget build() {
    _initScope();
    return _ScopeProvider(scope: _scope, child: (widget as LScope<T>).child);
  }

  @override
  void unmount() {
    if (_scopeInitialized) {
      _scope.reset(force: true);
    }
    super.unmount();
  }
}

/// A widget that manages multiple dependency injection bindings in a single scope.
class LMultiScope extends Widget {
  final List<LMultiScopeBinding> scopes;
  final Widget child;
  final String? name;

  const LMultiScope({
    super.key,
    required this.scopes,
    required this.child,
    this.name,
  });

  @override
  Element createElement() => LMultiScopeElement(this);
}

class LMultiScopeElement extends ComponentElement {
  LMultiScopeElement(LMultiScope super.widget);

  late LevitScope _scope;
  bool _scopeInitialized = false;

  void _initScope() {
    if (_scopeInitialized) return;
    final widget = this.widget as LMultiScope;
    final scopeName = widget.name ?? 'LMultiScope';
    _scope = _createChildScope(this, scopeName);
    for (final scope in widget.scopes) {
      scope._registerIn(_scope);
    }
    _scopeInitialized = true;
  }

  @override
  void update(LMultiScope newWidget) {
    super.update(newWidget);
    markNeedsBuild();
    rebuild();
  }

  @override
  Widget build() {
    _initScope();
    return _ScopeProvider(scope: _scope, child: (widget as LMultiScope).child);
  }

  @override
  void unmount() {
    if (_scopeInitialized) {
      _scope.reset(force: true);
    }
    super.unmount();
  }
}

/// Configuration for a single binding in [LMultiScope].
class LMultiScopeBinding<T> {
  final T Function() init;
  final String? tag;
  final bool permanent;

  const LMultiScopeBinding(this.init, {this.tag, this.permanent = false});

  void _registerIn(LevitScope scope) {
    scope.put<T>(init, tag: tag, permanent: permanent);
  }
}

/// Helper class for scoped DI access via [BuildContext].
class LevitProvider {
  final BuildContext _context;

  LevitProvider(this._context);

  S find<S>({String? tag}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.find<S>(tag: tag);
    }
    return Levit.find<S>(tag: tag);
  }

  bool isRegistered<S>({String? tag}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.isRegistered<S>(tag: tag);
    }
    return Levit.isRegistered<S>(tag: tag);
  }

  S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.put<S>(builder, tag: tag, permanent: permanent);
    }
    return Levit.put<S>(builder, tag: tag, permanent: permanent);
  }

  S putOrFind<S>(S Function() builder, {String? tag, bool permanent = false}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      final instance = scope.findOrNull<S>(tag: tag);
      if (instance != null) return instance;
      return scope.put<S>(builder, tag: tag, permanent: permanent);
    }

    final instance = Levit.findOrNull<S>(tag: tag);
    if (instance != null) return instance;
    return Levit.put<S>(builder, tag: tag, permanent: permanent);
  }
}

/// Extension to access scoped DI via [BuildContext].
extension LevitProviderExtension on BuildContext {
  LevitProvider get levit => LevitProvider(this);
}

/// A convenience widget for scoped View.
abstract class LScopedView<T> extends Widget {
  const LScopedView({super.key});

  String? get tag => null;
  bool get permanent => false;
  bool get autoWatch => true;

  T createController();
  Widget buildContent(BuildContext context, T controller);

  @override
  Element createElement() => LScopedViewElement<T>(this);
}

class LScopedViewElement<T> extends ComponentElement {
  LScopedViewElement(LScopedView<T> super.widget);

  late LevitScope _scope;
  late T _controller;
  bool _scopeInitialized = false;

  void _initScope() {
    if (_scopeInitialized) return;
    final widget = this.widget as LScopedView<T>;
    final scopeName = 'LScopedView<${T.toString()}>';
    _scope = _createChildScope(this, scopeName);

    _controller = _scope.put<T>(() => widget.createController(),
        tag: widget.tag, permanent: widget.permanent);

    _scopeInitialized = true;
  }

  @override
  void update(LScopedView<T> newWidget) {
    super.update(newWidget);
    markNeedsBuild();
    rebuild();
  }

  @override
  Widget build() {
    _initScope();
    final widget = this.widget as LScopedView<T>;

    final content = widget.autoWatch
        ? LWatch(() => widget.buildContent(this, _controller))
        : widget.buildContent(this, _controller);

    return _ScopeProvider(scope: _scope, child: content);
  }

  @override
  void unmount() {
    if (_scopeInitialized) {
      _scope.reset(force: true);
    }
    super.unmount();
  }
}
