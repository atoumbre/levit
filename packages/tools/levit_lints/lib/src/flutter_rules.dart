part of 'rules.dart';

/// Flags a top-level `LWatch` returned directly from an `LView`, `LScopedView`,
/// or `LAsyncView` that already has `autoWatch` enabled
/// (`avoid_redundant_outer_lwatch`).
///
/// When `autoWatch` is `true` (the default), `LView`, `LScopedView`, and
/// `LAsyncView` already wrap `buildView` / `builder` in an `LWatch`. Returning
/// another `LWatch` as the root widget duplicates tracking without narrowing
/// rebuild scope.
///
/// **Bad:**
/// ```dart
/// LScopedView<CounterController>.put(
///   () => CounterController(),
///   builder: (context, controller) => LWatch(
///     () => Text('${controller.count()}'),
///   ),
/// );
/// ```
///
/// **Good:**
/// ```dart
/// LScopedView<CounterController>.put(
///   () => CounterController(),
///   builder: (context, controller) => Text('${controller.count()}'),
/// );
/// ```
///
/// Suppress with `// ignore: levit_lints/avoid_redundant_outer_lwatch`.
///
/// {@category Flutter Rules}
class AvoidRedundantOuterLWatch extends AnalysisRule {
  /// Diagnostic code reported when an `autoWatch`-enabled view returns a
  /// root `LWatch`.
  static const LintCode code = LintCode(
    'avoid_redundant_outer_lwatch',
    'This view already watches reactive reads because autoWatch is enabled.',
    correctionMessage:
        'Remove the outer LWatch, or set autoWatch: false and wrap only '
        'narrower subtrees in LWatch.',
  );

  /// Creates the `avoid_redundant_outer_lwatch` analysis rule.
  AvoidRedundantOuterLWatch()
    : super(
        name: code.lowerCaseName,
        description:
            'Avoid wrapping the entire buildView/builder result in an outer '
            'LWatch when autoWatch is enabled.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _RedundantOuterLWatchVisitor(this);
    registry
      ..addInstanceCreationExpression(this, visitor)
      ..addMethodDeclaration(this, visitor);
  }
}

class _RedundantOuterLWatchVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _RedundantOuterLWatchVisitor(this.rule);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!_isLevitAutoWatchViewType(node.staticType)) return;
    if (!_isAutoWatchEnabledInArguments(node.argumentList)) return;

    for (final arg in node.argumentList.arguments) {
      if (arg is NamedArgument &&
          arg.name.lexeme == 'builder' &&
          arg.argumentExpression is FunctionExpression) {
        final returned = _singleReturnedExpression(
          (arg.argumentExpression as FunctionExpression).body,
        );
        if (returned != null && _isLWatchCreation(returned)) {
          rule.reportAtNode(_unwrapParentheses(returned));
        }
      }
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.isStatic || node.name.lexeme != 'buildView') return;
    final owner = _enclosingInterfaceElement(node);
    if (owner == null || !_isLevitAutoWatchViewType(owner.thisType)) return;
    if (_classDisablesAutoWatch(node)) return;

    final returned = _singleReturnedExpression(node.body);
    if (returned != null && _isLWatchCreation(returned)) {
      rule.reportAtNode(_unwrapParentheses(returned));
    }
  }

  bool _isAutoWatchEnabledInArguments(ArgumentList argumentList) {
    for (final arg in argumentList.arguments) {
      if (arg is NamedArgument && arg.name.lexeme == 'autoWatch') {
        final expr = _unwrapParentheses(arg.argumentExpression);
        // Report only when autoWatch is statically true; skip false or dynamic.
        return expr is BooleanLiteral && expr.value;
      }
    }
    return true;
  }

  bool _classDisablesAutoWatch(MethodDeclaration method) {
    AstNode? current = method.parent;
    while (current != null && current is! ClassDeclaration) {
      current = current.parent;
    }
    if (current is! ClassDeclaration) return false;
    final body = current.body;
    if (body is! BlockClassBody) return false;

    for (final member in body.members) {
      if (member is! ConstructorDeclaration) continue;
      for (final param in member.parameters.parameters) {
        if (param is SuperFormalParameter && param.name.lexeme == 'autoWatch') {
          return true;
        }
      }
      for (final init in member.initializers) {
        if (init is SuperConstructorInvocation) {
          for (final arg in init.argumentList.arguments) {
            if (arg is NamedArgument && arg.name.lexeme == 'autoWatch') {
              final expr = _unwrapParentheses(arg.argumentExpression);
              if (expr is! BooleanLiteral || !expr.value) return true;
            }
          }
        }
      }
    }
    return false;
  }
}

/// Flags raw `showDialog` and `showModalBottomSheet` calls inside Flutter
/// widgets in Levit-importing files when the overlay is not wrapped in
/// `LScope.capture` (`avoid_unscoped_overlay`).
///
/// Imperative overlay routes mount on the navigator above the caller's
/// `LScope`, so `context.levit.find` inside the dialog or sheet loses access
/// to page-local dependencies unless `showLevitDialog`,
/// `showLevitModalBottomSheet`, or `LScope.capture` is used.
///
/// **Bad:**
/// ```dart
/// showDialog<void>(
///   context: context,
///   builder: (context) => const EditDialog(),
/// );
/// ```
///
/// **Good:**
/// ```dart
/// showLevitDialog<void>(
///   context: context,
///   builder: (context) => const EditDialog(),
/// );
/// ```
///
/// Suppress with `// ignore: levit_lints/avoid_unscoped_overlay`.
///
/// {@category Flutter Rules}
class AvoidUnscopedOverlay extends AnalysisRule {
  /// Diagnostic code reported when raw `showDialog` or
  /// `showModalBottomSheet` bypasses Levit scope capture.
  static const LintCode code = LintCode(
    'avoid_unscoped_overlay',
    'Overlay route does not capture the caller Levit scope.',
    correctionMessage:
        'Use showLevitDialog / showLevitModalBottomSheet or wrap the overlay '
        'child with LScope.capture(context, child: ...).',
  );

  /// Creates the `avoid_unscoped_overlay` analysis rule.
  AvoidUnscopedOverlay()
    : super(
        name: code.lowerCaseName,
        description:
            'Prefer scope-preserving overlay helpers or LScope.capture inside '
            'Levit Flutter widgets.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, _UnscopedOverlayVisitor(this));
  }
}

class _UnscopedOverlayVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _UnscopedOverlayVisitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (name != 'showDialog' && name != 'showModalBottomSheet') return;

    final element = node.methodName.element;
    final libraryUri = element?.library?.uri.toString();
    if (libraryUri == null || !libraryUri.startsWith('package:flutter/')) {
      return;
    }

    if (!_isInsideFlutterWidgetOrState(node)) return;
    if (!_unitImportsLevitFlutter(node)) return;
    if (_overlayCapturesScope(node)) return;

    rule.reportAtNode(node);
  }

  bool _unitImportsLevitFlutter(AstNode node) {
    final root = node.root;
    if (root is! CompilationUnit) return false;
    for (final directive in root.directives) {
      if (directive is ImportDirective) {
        final uri = directive.uri.stringValue;
        if (uri != null &&
            (uri.startsWith('package:levit_flutter/') ||
                uri.startsWith('package:levit_flutter_core/'))) {
          return true;
        }
      }
    }
    return false;
  }

  bool _overlayCapturesScope(MethodInvocation node) {
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedArgument && arg.name.lexeme == 'builder') {
        final visitor = _ScopeCaptureCallVisitor();
        arg.argumentExpression.accept(visitor);
        if (visitor.found) return true;
      }
    }
    return false;
  }
}

class _ScopeCaptureCallVisitor extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'capture' && _isLevitScopeCapture(node)) {
      found = true;
      return;
    }
    super.visitMethodInvocation(node);
  }

  bool _isLevitScopeCapture(MethodInvocation node) {
    final member = node.methodName.element;
    final uri = member?.library?.uri;
    return member?.enclosingElement?.name == 'LScope' &&
        uri != null &&
        uri.scheme == 'package' &&
        const {
          'levit_flutter_core',
          'levit_flutter',
        }.contains(uri.pathSegments.first);
  }
}

bool _isInsideFlutterWidgetOrState(AstNode node) {
  final owner = _enclosingInterfaceElement(node);
  if (owner == null) return false;
  return [owner.thisType, ...owner.allSupertypes].any(
    (type) =>
        const {'Widget', 'State'}.contains(type.element.name) &&
        type.element.library.uri.toString().startsWith('package:flutter/'),
  );
}

bool _isLevitAutoWatchViewType(DartType? type) {
  if (type is! InterfaceType) return false;
  for (final candidate in [type, ...type.element.allSupertypes]) {
    final uri = candidate.element.library.uri;
    if (uri.scheme == 'package' &&
        const {
          'levit_flutter_core',
          'levit_flutter',
        }.contains(uri.pathSegments.first) &&
        const {
          'LView',
          'LScopedView',
          'LAsyncView',
        }.contains(candidate.element.name)) {
      return true;
    }
  }
  return false;
}

bool _isLWatchCreation(Expression expression) {
  final unwrapped = _unwrapParentheses(expression);
  if (unwrapped is! InstanceCreationExpression) return false;
  final type = unwrapped.staticType;
  if (type is! InterfaceType) return false;
  final uri = type.element.library.uri;
  return type.element.name == 'LWatch' &&
      uri.scheme == 'package' &&
      const {
        'levit_flutter_core',
        'levit_flutter',
      }.contains(uri.pathSegments.first);
}
