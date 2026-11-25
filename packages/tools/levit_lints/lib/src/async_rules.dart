part of 'rules.dart';

/// Requires async lifecycle delegation to be awaited or directly returned.
/// This local check does not prove that every control-flow path delegates.
class AwaitLevitLifecycle extends AnalysisRule {
  static const code = LintCode(
    'await_levit_lifecycle',
    'Async Levit lifecycle delegation must complete before this override.',
    correctionMessage: 'Await or directly return the super lifecycle call.',
  );
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
        !_declaringLevitTypes(node).any(
          (name) => const {
            'LevitController',
            'LevitResourceOwner',
            'LevitResourceOwnership',
          }.contains(name),
        ) ||
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

/// Flags global lookup from resolved Flutter Widget/State implementations.
/// The runtime widget tree cannot be inferred; use context lookup in all such code.
class AvoidGlobalLevitInWidgets extends AnalysisRule {
  static const code = LintCode(
    'avoid_global_levit_in_widgets',
    'Global Levit resolution bypasses the widget scope.',
    correctionMessage: 'Resolve with context.levit in widget code.',
  );
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

/// Detects a directly discarded Future from a known Levit lifecycle/worker API.
/// Explicit unawaited calls, stored futures and returned futures are allowed.
class DiscardedLevitFuture extends AnalysisRule {
  static const code = LintCode(
    'discarded_levit_future',
    'This Levit operation completes asynchronously and its future is discarded.',
    correctionMessage:
        'Await, return, retain, or explicitly handle the future.',
  );
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
      'LxWorkerImpl': {'close'},
      'LevitLoopService': {'stop'},
      'LevitLoopEngine': {'stopService', 'stopAllServices', 'dispose'},
      'LevitTaskEngine': {'dispose'},
      'LevitTaskGroup': {'dispose', 'drain'},
      'LxResource': {'refresh', 'drain', 'close'},
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
      'LevitResourceOwnership': {'onClose', 'onBeforeClose'},
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
