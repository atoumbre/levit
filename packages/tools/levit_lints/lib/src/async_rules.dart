part of 'rules.dart';

/// Requires async `super.onInit`, `super.onBeforeClose`, and `super.onClose`
/// calls to be awaited or directly returned (`await_levit_lifecycle`).
///
/// Applies to `Future`/`FutureOr`-returning `super` lifecycle calls resolved on
/// `LevitController`. Wrapping the call in `unawaited(...)` is not accepted for
/// lifecycle delegation because teardown ordering depends on completion.
///
/// **Bad:**
/// ```dart
/// class SyncController extends LevitController {
///   @override
///   Future<void> onBeforeClose() async {
///     super.onBeforeClose();
///     await flushQueue();
///   }
/// }
/// ```
///
/// **Good:**
/// ```dart
/// class SyncController extends LevitController {
///   @override
///   Future<void> onBeforeClose() async {
///     await super.onBeforeClose();
///     await flushQueue();
///   }
/// }
/// ```
///
/// This local check inspects each `super` invocation site; it does not prove
/// that every control-flow branch delegates. Suppress with
/// `// ignore: levit_lints/await_levit_lifecycle`.
///
/// {@category Lifecycle Rules}
class AwaitLevitLifecycle extends AnalysisRule {
  /// Diagnostic code reported when an async `super` lifecycle call is neither
  /// awaited nor directly returned.
  static const code = LintCode(
    'await_levit_lifecycle',
    'Async Levit lifecycle delegation must complete before this override.',
    correctionMessage: 'Await or directly return the super lifecycle call.',
  );

  /// Creates the `await_levit_lifecycle` analysis rule.
  AwaitLevitLifecycle()
    : super(
        name: code.lowerCaseName,
        description: 'Await async lifecycle delegation.',
      );
  @override
  LintCode get diagnosticCode => code;
  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, _AwaitLifecycleVisitor(this));
  }
}

class _AwaitLifecycleVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  _AwaitLifecycleVisitor(this.rule);
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target is! SuperExpression ||
        !const {
          'onInit',
          'onBeforeClose',
          'onClose',
        }.contains(node.methodName.name) ||
        !_declaringLevitTypes(node).any((name) => name == 'LevitController') ||
        !_isAsync(node.staticType)) {
      return;
    }
    AstNode expression = node;
    while (expression.parent is ParenthesizedExpression) {
      expression = expression.parent!;
    }
    final parent = expression.parent;
    if (parent is AwaitExpression ||
        parent is ReturnStatement ||
        parent is ExpressionFunctionBody) {
      return;
    }
    rule.reportAtNode(node);
  }
}

/// Flags global `Levit.find*` lookups inside Flutter `Widget` and `State`
/// subclasses (`avoid_global_levit_in_widgets`).
///
/// Resolves `Levit.find`, `Levit.findOrNull`, `Levit.findAsync`, and
/// `Levit.findOrNullAsync` from Levit libraries (including aliased imports) and
/// recommends resolving via `context.levit.find*` so dependencies respect the
/// active `LScope` subtree.
///
/// **Bad:**
/// ```dart
/// class CounterView extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final controller = Levit.find<CounterController>();
///     return Text('${controller.count.value}');
///   }
/// }
/// ```
///
/// **Good:**
/// ```dart
/// class CounterView extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final controller = context.levit.find<CounterController>();
///     return Text('${controller.count.value}');
///   }
/// }
/// ```
///
/// Because static analysis cannot infer the runtime widget tree, this rule
/// flags all global lookups in Flutter `Widget`/`State` classes and does not
/// inspect arbitrary top-level helper functions. Suppress an intentional root
/// lookup with `// ignore: levit_lints/avoid_global_levit_in_widgets`.
///
/// {@category Flutter Rules}
class AvoidGlobalLevitInWidgets extends AnalysisRule {
  /// Diagnostic code reported for global `Levit.find*` calls inside Flutter
  /// `Widget` or `State` subclasses.
  static const code = LintCode(
    'avoid_global_levit_in_widgets',
    'Global Levit resolution bypasses the widget scope.',
    correctionMessage: 'Resolve with context.levit in widget code.',
  );

  /// Creates the `avoid_global_levit_in_widgets` analysis rule.
  AvoidGlobalLevitInWidgets()
    : super(
        name: code.lowerCaseName,
        description: 'Use the widget scope for resolution.',
      );
  @override
  LintCode get diagnosticCode => code;
  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, _GlobalLookupVisitor(this));
  }
}

class _GlobalLookupVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  _GlobalLookupVisitor(this.rule);
  @override
  void visitMethodInvocation(MethodInvocation node) {
    final member = node.methodName.element;
    if (!_isLevitMember(node) ||
        member?.enclosingElement?.name != 'Levit' ||
        !const {
          'find',
          'findOrNull',
          'findAsync',
          'findOrNullAsync',
        }.contains(node.methodName.name)) {
      return;
    }
    final owner = _enclosingInterfaceElement(node);
    if (owner == null) return;
    if ([owner.thisType, ...owner.allSupertypes].any(
      (type) =>
          const {'Widget', 'State'}.contains(type.element.name) &&
          type.element.library.uri.toString().startsWith('package:flutter/'),
    )) {
      rule.reportAtNode(node);
    }
  }
}

/// Detects directly discarded `Future`/`FutureOr` return values from known
/// Levit disposal, scope, task, loop, and reactive cleanup APIs
/// (`discarded_levit_future`).
///
/// Checks resolved calls on `Levit` (`delete`, `reset`, `runInScope`),
/// `LevitScope`, `LevitScopeDisposable`, `LevitController`,
/// `LevitScopeLifecycleController`, `LxReactive`, `LxBase`, `LxWorker`,
/// `LevitAsyncMap`, `LevitLoopService`, `LevitLoopEngine`, `LevitTaskEngine`,
/// and `LevitTaskGroup`.
///
/// `super.*` lifecycle invocations are intentionally excluded here and handled
/// by [AwaitLevitLifecycle]. Awaiting, returning, storing, or explicitly
/// wrapping the future in `unawaited(...)` satisfies this rule.
///
/// **Bad:**
/// ```dart
/// void shutdown(LevitScope scope, LxWorker worker) {
///   worker.close();
///   scope.dispose();
/// }
/// ```
///
/// **Good:**
/// ```dart
/// Future<void> shutdown(LevitScope scope, LxWorker worker) async {
///   await worker.close();
///   await scope.dispose();
/// }
/// ```
///
/// Suppress with `// ignore: levit_lints/discarded_levit_future`.
///
/// {@category Lifecycle Rules}
class DiscardedLevitFuture extends AnalysisRule {
  /// Diagnostic code reported when a `Future` from a tracked Levit lifecycle or
  /// worker API is directly discarded.
  static const code = LintCode(
    'discarded_levit_future',
    'This Levit operation completes asynchronously and its future is discarded.',
    correctionMessage:
        'Await, return, retain, or explicitly handle the future.',
  );

  /// Creates the `discarded_levit_future` analysis rule.
  DiscardedLevitFuture()
    : super(
        name: code.lowerCaseName,
        description: 'Observe known Levit cleanup and worker futures.',
      );
  @override
  LintCode get diagnosticCode => code;
  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addExpressionStatement(this, _DiscardedFutureVisitor(this));
  }
}

class _DiscardedFutureVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  _DiscardedFutureVisitor(this.rule);
  @override
  void visitExpressionStatement(ExpressionStatement node) {
    final expression = _unwrapParentheses(node.expression);
    if (expression is! MethodInvocation ||
        !_isAsync(expression.staticType) ||
        expression.target is SuperExpression) {
      return;
    }
    final owners = _declaringLevitTypes(expression);
    final method = expression.methodName.name;
    const operations = <String, Set<String>>{
      'Levit': {'delete', 'reset', 'runInScope'},
      'LevitScope': {
        'dispose',
        'delete',
        'reset',
        'releaseFactoryInstance',
        'waitForInitialization',
      },
      'LevitScopeDisposable': {'onClose'},
      'LevitController': {'onClose', 'onBeforeClose'},
      'LevitScopeLifecycleController': {'close', 'replace', 'retry'},
      'LxReactive': {'close'},
      'LxBase': {'close'},
      'LxWorker': {'close'},
      'LevitLoopService': {'stop'},
      'LevitLoopEngine': {'stopService', 'stopAllServices', 'dispose'},
      'LevitTaskEngine': {'dispose'},
      'LevitTaskGroup': {'dispose', 'drain'},
      'LevitAsyncMap': {
        'fetch',
        'refresh',
        'evict',
        'invalidate',
        'invalidateAll',
        'drain',
        'close',
        'dispose',
      },
    };
    if (owners.any((owner) => operations[owner]?.contains(method) ?? false)) {
      rule.reportAtNode(expression);
    }
  }
}

bool _isAsync(DartType? type) =>
    type?.isDartAsyncFuture == true || type?.isDartAsyncFutureOr == true;

bool _isLevitMember(MethodInvocation node) {
  final uri = node.methodName.element?.library?.uri;
  return uri?.scheme == 'package' &&
      const {
        'levit_scope',
        'levit_reactive',
        'levit_dart_core',
        'levit_flutter_core',
        'levit_dart',
      }.contains(uri!.pathSegments.first);
}

Iterable<String?> _declaringLevitTypes(MethodInvocation node) sync* {
  final owner = node.methodName.element?.enclosingElement;
  if (owner is! InterfaceElement) return;
  for (final type in [owner.thisType, ...owner.allSupertypes]) {
    final uri = type.element.library.uri;
    if (uri.scheme == 'package' &&
        const {
          'levit_scope',
          'levit_reactive',
          'levit_dart_core',
          'levit_flutter_core',
          'levit_dart',
        }.contains(uri.pathSegments.first)) {
      yield type.element.name;
    }
  }
}
