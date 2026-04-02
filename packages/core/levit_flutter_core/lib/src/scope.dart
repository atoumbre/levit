part of '../levit_flutter_core.dart';

typedef LScopeDependencyFactory = void Function(LevitScope scope);
typedef LAsyncScopeDependencyFactory = FutureOr<void> Function(
  LevitScope scope,
);

/// An internal widget that propagates the [LevitScope] down the widget tree.
class _ScopeProvider extends InheritedWidget {
  final LevitScope scope;

  const _ScopeProvider({
    required this.scope,
    required super.child,
  });

  static LevitScope? of(BuildContext context, {bool listen = false}) {
    final provider = listen
        ? context.dependOnInheritedWidgetOfExactType<_ScopeProvider>()
        : context.getInheritedWidgetOfExactType<_ScopeProvider>();
    return provider?.scope;
  }

  @override
  bool updateShouldNotify(_ScopeProvider oldWidget) => scope != oldWidget.scope;
}

class _CapturedScope extends StatelessWidget {
  final LevitScope scope;
  final Widget child;

  const _CapturedScope({
    required this.scope,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _ScopeProvider(
      scope: scope,
      child: child,
    );
  }
}

bool _scopeArgsMatch(List<Object?>? a, List<Object?>? b) {
  if (a == null || b == null) return identical(a, b);
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
