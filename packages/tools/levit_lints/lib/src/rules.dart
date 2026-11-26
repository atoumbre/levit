import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

part 'async_rules.dart';

/// Flags mutable plain `LxStatus` fields and retained `.status` snapshots on
/// Levit resource owners (`avoid_plain_lx_status_fields`).
///
/// Storing a raw `LxStatus` in a mutable field or capturing `.status` from an
/// `LxFuture`/`LxStream` into an instance field disconnects UI watchers from
/// reactive updates. Instead, store an `LxAsync`/`LxVar<LxStatus<T>>` or expose
/// a getter that reads the live `.status` on demand.
///
/// **Bad:**
/// ```dart
/// class UserController extends LevitController {
///   LxStatus<User> userStatus = LxIdle();
///   late final LxStatus<User> cached = userAsync.status;
/// }
/// ```
///
/// **Good:**
/// ```dart
/// class UserController extends LevitController {
///   final userAsync = LxAsync<User>();
///   LxStatus<User> get userStatus => userAsync.status;
/// }
/// ```
///
/// Only checks non-static fields declared inside `LevitResourceOwner` or
/// `LevitController` subtypes. Suppress with
/// `// ignore: levit_lints/avoid_plain_lx_status_fields`.
///
/// {@category Reactive Rules}
class AvoidPlainLxStatusFields extends AnalysisRule {
  /// Diagnostic code reported for mutable or snapshot `LxStatus` fields.
  static const LintCode code = LintCode(
    'avoid_plain_lx_status_fields',
    'This controller field stores a non-reactive LxStatus snapshot.',
    correctionMessage:
        'Store status in an LxReactive, or expose a getter that reads the '
        'source status on demand.',
  );

  /// Creates the `avoid_plain_lx_status_fields` analysis rule.
  AvoidPlainLxStatusFields()
    : super(
        name: 'avoid_plain_lx_status_fields',
        description:
            'Avoid stale or mutable plain LxStatus fields on resource owners.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addFieldDeclaration(this, _StatusFieldVisitor(this));
  }
}

class _StatusFieldVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _StatusFieldVisitor(this.rule);

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.isStatic || !_isInsideResourceOwner(node)) return;

    for (final variable in node.fields.variables) {
      final initializer = variable.initializer;
      final type = variable.declaredFragment?.element.type;
      if (!_isTypeNamed(type, 'LxStatus')) continue;

      final mutable = !node.fields.isFinal && !node.fields.isConst;
      final snapshot = initializer != null && _endsInStatusRead(initializer);
      if (mutable || snapshot) rule.reportAtToken(variable.name);
    }
  }
}

/// Flags `Levit.put(() => existingOwner)` registrations that return an already
/// constructed resource owner (`avoid_preconstructed_levit_put`).
///
/// Constructing a `LevitController` or `LevitResourceOwner` outside the
/// `Levit.put` builder prevents auto-linking from capturing reactive fields
/// created in the constructor and risks sharing or re-registering a disposed
/// instance.
///
/// **Bad:**
/// ```dart
/// final controller = CounterController();
/// Levit.put(() => controller);
/// ```
///
/// **Good:**
/// ```dart
/// Levit.put(() => CounterController());
/// ```
///
/// This local rule inspects `Levit.put` calls whose zero-argument builder
/// directly returns an identifier or property of a `LevitResourceOwner` /
/// `LevitController` subtype. Suppress with
/// `// ignore: levit_lints/avoid_preconstructed_levit_put`.
///
/// {@category Lifecycle Rules}
class AvoidPreconstructedLevitPut extends AnalysisRule {
  /// Diagnostic code reported for `Levit.put` builders returning an existing
  /// resource owner.
  static const LintCode code = LintCode(
    'avoid_preconstructed_levit_put',
    'Levit.put received a closure that returns a preconstructed owner.',
    correctionMessage:
        'Construct the controller or resource inside the Levit.put callback.',
  );

  /// Creates the `avoid_preconstructed_levit_put` analysis rule.
  AvoidPreconstructedLevitPut()
    : super(
        name: 'avoid_preconstructed_levit_put',
        description:
            'Keep construction inside Levit.put so auto-linking can capture '
            'the complete lifecycle.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, _PreconstructedPutVisitor(this));
  }
}

class _PreconstructedPutVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _PreconstructedPutVisitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'put' || node.target?.toSource() != 'Levit') {
      return;
    }
    if (node.argumentList.arguments.isEmpty) return;
    final first = node.argumentList.arguments.first;
    if (first is! FunctionExpression ||
        first.parameters?.parameters.isNotEmpty == true) {
      return;
    }

    final returned = _singleReturnedExpression(first.body);
    if (returned == null ||
        returned is! SimpleIdentifier &&
            returned is! PrefixedIdentifier &&
            returned is! PropertyAccess) {
      return;
    }
    if (!_isResourceOwnerType(returned.staticType)) return;
    rule.reportAtNode(returned);
  }
}

/// Requires `onInit`, `onBeforeClose`, and `onClose` overrides on Levit
/// resource owners to delegate to `super` (`must_call_super_levit_lifecycle`).
///
/// Omitting the superclass lifecycle call skips automatic disposal of owned
/// reactives, subscriptions, timers, and mixin resources.
///
/// **Bad:**
/// ```dart
/// class SessionController extends LevitController {
///   @override
///   Future<void> onClose() async {
///     await flushLogs();
///   }
/// }
/// ```
///
/// **Good:**
/// ```dart
/// class SessionController extends LevitController {
///   @override
///   Future<void> onClose() async {
///     await flushLogs();
///     await super.onClose();
///   }
/// }
/// ```
///
/// Applies to `LevitResourceOwner` and `LevitController` subtypes (excluding
/// `LevitController` itself). This is a local AST check that verifies a
/// matching `super.<hook>()` call exists in the method body; it does not prove
/// that every control-flow branch reaches it. Suppress with
/// `// ignore: levit_lints/must_call_super_levit_lifecycle`.
///
/// {@category Lifecycle Rules}
class MustCallSuperLevitLifecycle extends AnalysisRule {
  /// Diagnostic code reported when an owner lifecycle override omits its
  /// matching `super` call.
  static const LintCode code = LintCode(
    'must_call_super_levit_lifecycle',
    'This Levit lifecycle override does not call its super implementation.',
    correctionMessage:
        'Delegate to super.onInit(), super.onBeforeClose(), and super.onClose() as appropriate.',
  );

  /// Creates the `must_call_super_levit_lifecycle` analysis rule.
  MustCallSuperLevitLifecycle()
    : super(
        name: 'must_call_super_levit_lifecycle',
        description:
            'Preserve controller and mixin ownership cleanup across '
            'lifecycle overrides.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodDeclaration(this, _LifecycleSuperVisitor(this));
  }
}

class _LifecycleSuperVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _LifecycleSuperVisitor(this.rule);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final name = node.name.lexeme;
    if (name != 'onInit' && name != 'onBeforeClose' && name != 'onClose') {
      return;
    }
    final owner = _enclosingInterfaceElement(node);
    if (owner?.name == 'LevitController') return;
    if (node.isStatic || !node.isComplete || !_isInsideResourceOwner(node)) {
      return;
    }

    final visitor = _SuperLifecycleCallVisitor(name);
    node.body.accept(visitor);
    if (!visitor.found) rule.reportAtToken(node.name);
  }
}

class _SuperLifecycleCallVisitor extends RecursiveAstVisitor<void> {
  final String lifecycleName;
  bool found = false;

  _SuperLifecycleCallVisitor(this.lifecycleName);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target is SuperExpression &&
        node.methodName.name == lifecycleName) {
      found = true;
      return;
    }
    super.visitMethodInvocation(node);
  }
}

/// Flags unowned subscriptions, timers, and `late` reactive fields inside Levit
/// resource owners (`unowned_levit_resource`).
///
/// Reports two resource-leak patterns inside `LevitResourceOwner` and
/// `LevitController` subtypes:
/// 1. Statement-level discarded `StreamSubscription` or `Timer` expressions not
///    wrapped in `own(...)`.
/// 2. Non-static `late` fields initialized with an `LxReactive`/`LxBase`
///    expression outside `own(...)` (lazy initialization runs after constructor
///    auto-linking finishes).
///
/// **Bad:**
/// ```dart
/// class FeedController extends LevitController {
///   late final items = <String>[].lx;
///
///   @override
///   void onInit() {
///     super.onInit();
///     Timer.periodic(const Duration(seconds: 5), (_) => refresh());
///   }
/// }
/// ```
///
/// **Good:**
/// ```dart
/// class FeedController extends LevitController {
///   late final items = own(<String>[].lx);
///
///   @override
///   void onInit() {
///     super.onInit();
///     own(Timer.periodic(const Duration(seconds: 5), (_) => refresh()));
///   }
/// }
/// ```
///
/// Suppress with `// ignore: levit_lints/unowned_levit_resource`.
///
/// {@category Lifecycle Rules}
class UnownedLevitResource extends AnalysisRule {
  /// Diagnostic code reported for discarded subscriptions/timers and unowned
  /// `late` reactive fields.
  static const LintCode code = LintCode(
    'unowned_levit_resource',
    'This lifecycle resource is not owned by its Levit resource owner.',
    correctionMessage:
        'Wrap the resource in own(...), or return/store it '
        'behind an explicit lifecycle contract.',
  );

  /// Creates the `unowned_levit_resource` analysis rule.
  UnownedLevitResource()
    : super(
        name: 'unowned_levit_resource',
        description:
            'Prevent discarded subscriptions, timers, and lazy reactive '
            'fields from escaping owner disposal.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _UnownedResourceVisitor(this);
    registry
      ..addExpressionStatement(this, visitor)
      ..addFieldDeclaration(this, visitor);
  }
}

class _UnownedResourceVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _UnownedResourceVisitor(this.rule);

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    if (!_isInsideResourceOwner(node)) return;
    final expression = _unwrapParentheses(node.expression);
    if (_isOwnedExpression(expression)) return;
    final type = expression.staticType;
    if (_isTypeNamed(type, 'StreamSubscription') ||
        _isTypeNamed(type, 'Timer')) {
      rule.reportAtNode(expression);
    }
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.isStatic ||
        node.fields.lateKeyword == null ||
        !_isInsideResourceOwner(node)) {
      return;
    }
    for (final variable in node.fields.variables) {
      final initializer = variable.initializer;
      if (initializer == null ||
          _isOwnedExpression(initializer) ||
          !_isReactiveType(initializer.staticType)) {
        continue;
      }
      rule.reportAtToken(variable.name);
    }
  }
}

Expression _unwrapParentheses(Expression expression) {
  var current = expression;
  while (current is ParenthesizedExpression) {
    current = current.expression;
  }
  return current;
}

bool _isOwnedExpression(Expression expression) {
  final current = _unwrapParentheses(expression);
  return current is MethodInvocation && current.methodName.name == 'own';
}

bool _endsInStatusRead(Expression expression) {
  final current = _unwrapParentheses(expression);
  return switch (current) {
    PropertyAccess(:final propertyName) => propertyName.name == 'status',
    PrefixedIdentifier(:final identifier) => identifier.name == 'status',
    _ => false,
  };
}

Expression? _singleReturnedExpression(FunctionBody body) {
  return switch (body) {
    ExpressionFunctionBody(:final expression) => expression,
    BlockFunctionBody(:final block)
        when block.statements.length == 1 &&
            block.statements.single is ReturnStatement =>
      (block.statements.single as ReturnStatement).expression,
    _ => null,
  };
}

bool _isInsideResourceOwner(AstNode node) {
  final element = _enclosingInterfaceElement(node);
  return element != null && _isResourceOwnerType(element.thisType);
}

InterfaceElement? _enclosingInterfaceElement(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    final element = switch (current) {
      ClassDeclaration(:final declaredFragment) => declaredFragment?.element,
      MixinDeclaration(:final declaredFragment) => declaredFragment?.element,
      _ => null,
    };
    if (element is InterfaceElement) {
      return element;
    }
    current = current.parent;
  }
  return null;
}

bool _isResourceOwnerType(DartType? type) {
  return _isTypeNamed(type, 'LevitResourceOwner') ||
      _isTypeNamed(type, 'LevitController');
}

bool _isReactiveType(DartType? type) =>
    _isTypeNamed(type, 'LxReactive') || _isTypeNamed(type, 'LxBase');

bool _isTypeNamed(DartType? type, String name) {
  if (type is! InterfaceType) return false;
  if (type.element.name == name) return true;
  return type.element.allSupertypes.any((item) => item.element.name == name);
}
