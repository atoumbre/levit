import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:levit_lints/src/rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidPlainLxStatusFieldsTest);
    defineReflectiveTests(AvoidPreconstructedLevitPutTest);
    defineReflectiveTests(MustCallSuperLevitLifecycleTest);
    defineReflectiveTests(UnownedLevitResourceTest);
  });
}

const _ownerStub = r'''
abstract class LevitResourceOwner {
  T own<T>(T resource) => resource;
  T autoDispose<T>(T resource) => resource;
}

abstract class LevitController implements LevitResourceOwner {
  @override
  T own<T>(T resource) => resource;
  @override
  T autoDispose<T>(T resource) => resource;
  void onInit() {}
  void onClose() {}
}
''';

@reflectiveTest
class AvoidPlainLxStatusFieldsTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidPlainLxStatusFields();
    super.setUp();
  }

  Future<void> test_mutableAndSnapshot() async {
    final source =
        '''
$_ownerStub
class LxStatus<T> {}
class AsyncSource {
  LxStatus<int> get status => LxStatus<int>();
}

class Controller extends LevitController {
  LxStatus<int> mutable = LxStatus<int>();
  final source = AsyncSource();
  late final snapshot = source.status;
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('mutable ='), 'mutable'.length),
      lint(source.indexOf('snapshot ='), 'snapshot'.length),
    ]);
  }

  Future<void> test_reactiveOrLiveReadIsAllowed() async {
    await assertNoDiagnostics('''
$_ownerStub
class LxStatus<T> {}
class LxReactive<T> {
  final T value;
  LxReactive(this.value);
}
class AsyncSource {
  LxStatus<int> get status => LxStatus<int>();
}

class Controller extends LevitController {
  final LxStatus<int> initial = LxStatus<int>();
  final reactive = LxReactive<LxStatus<int>>(LxStatus<int>());
  final source = AsyncSource();
  LxStatus<int> get status => source.status;
}
''');
  }

  Future<void> test_unrelatedClassIsIgnored() async {
    await assertNoDiagnostics('''
class LxStatus<T> {}
class Plain {
  LxStatus<int> mutable = LxStatus<int>();
}
''');
  }
}

@reflectiveTest
class AvoidPreconstructedLevitPutTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidPreconstructedLevitPut();
    super.setUp();
  }

  Future<void> test_existingOwner() async {
    final source =
        '''
$_ownerStub
class Levit {
  static T put<T>(T Function() builder) => builder();
}
class Controller extends LevitController {}

void register() {
  final controller = Controller();
  Levit.put(() => controller);
}
''';

    await assertDiagnostics(source, [
      lint(source.lastIndexOf('controller);'), 'controller'.length),
    ]);
  }

  Future<void> test_existingOwnerReturnedFromBlock() async {
    final source =
        '''
$_ownerStub
class Levit {
  static T put<T>(T Function() builder) => builder();
}
class Controller extends LevitController {}

void register() {
  final controller = Controller();
  Levit.put(() {
    return controller;
  });
}
''';

    await assertDiagnostics(source, [
      lint(source.lastIndexOf('controller;'), 'controller'.length),
    ]);
  }

  Future<void> test_inlineConstructionAndFactoryCallAreAllowed() async {
    await assertNoDiagnostics('''
$_ownerStub
class Levit {
  static T put<T>(T Function() builder) => builder();
}
class Controller extends LevitController {}
Controller makeController() => Controller();

void register() {
  Levit.put(() => Controller());
  Levit.put(() => makeController());
}
''');
  }
}

@reflectiveTest
class MustCallSuperLevitLifecycleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = MustCallSuperLevitLifecycle();
    super.setUp();
  }

  Future<void> test_missingBothSuperCalls() async {
    final source =
        '''
$_ownerStub
class Controller extends LevitController {
  @override
  void onInit() {}

  @override
  void onClose() {
    final cleanup = true;
  }
}
''';

    await assertDiagnostics(source, [
      lint(
        source.indexOf('onInit()', source.indexOf('class Controller')),
        'onInit'.length,
      ),
      lint(
        source.indexOf('onClose() {', source.indexOf('class Controller')),
        'onClose'.length,
      ),
    ]);
  }

  Future<void> test_superCallsInBlockAndExpressionBodies() async {
    await assertNoDiagnostics('''
$_ownerStub
class Controller extends LevitController {
  @override
  void onInit() {
    helper();
    super.onInit();
  }

  @override
  void onClose() => super.onClose();

  void helper() {}
}
''');
  }

  Future<void> test_unrelatedLifecycleMethodsAreIgnored() async {
    await assertNoDiagnostics('''
class Plain {
  void onInit() {}
  void onClose() {}
}
''');
  }
}

@reflectiveTest
class UnownedLevitResourceTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = UnownedLevitResource();
    super.setUp();
  }

  Future<void> test_discardedSubscriptionAndTimer() async {
    final source =
        '''
import 'dart:async';
$_ownerStub
class Controller extends LevitController {
  void start(Stream<int> values) {
    (values.listen((_) {}));
    Timer(Duration.zero, () {});
  }
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('values.listen'), 'values.listen((_) {})'.length),
      lint(
        source.indexOf('Timer(Duration'),
        'Timer(Duration.zero, () {})'.length,
      ),
    ]);
  }

  Future<void> test_ownedResourcesAreAllowed() async {
    await assertNoDiagnostics('''
import 'dart:async';
$_ownerStub
class Controller extends LevitController {
  void start(Stream<int> values) {
    own(values.listen((_) {}));
    autoDispose(Timer(Duration.zero, () {}));
  }
}
''');
  }

  Future<void> test_lazyReactiveMustBeExplicitlyOwned() async {
    final source =
        '''
$_ownerStub
class LxReactive<T> {}
extension ReactiveExtension<T> on T {
  LxReactive<T> get lx => LxReactive<T>();
}
class Controller extends LevitController {
  late final state = 0.lx;
  late final owned = own(1.lx);
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('state ='), 'state'.length),
    ]);
  }

  Future<void> test_nonOwnerIsIgnored() async {
    await assertNoDiagnostics('''
import 'dart:async';
class Plain {
  void start(Stream<int> values) {
    values.listen((_) {});
    Timer(Duration.zero, () {});
  }
}
''');
  }
}

// ignore_for_file: non_constant_identifier_names
