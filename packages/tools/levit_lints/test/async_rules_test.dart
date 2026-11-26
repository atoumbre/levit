// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:levit_lints/src/rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AwaitLifecycleTest);
    defineReflectiveTests(GlobalLookupTest);
    defineReflectiveTests(DiscardedFutureTest);
  });
}

mixin ApiFixtures on AnalysisRuleTest {
  void installApis() {
    newPackage('levit_dart_core').addFile('lib/levit_dart_core.dart', '''
import 'dart:async';
class LevitController {
  FutureOr<void> onInit() {}
  Future<void> onBeforeClose() async {}
  void onClose() {}
}
class LevitScope { Future<void> dispose() async {} }
class Levit {
  static T find<T>() => throw UnimplementedError();
  static Future<T> findAsync<T>() async => find<T>();
  static Future<void> reset() async {}
}
''');
    newPackage('levit_reactive').addFile('lib/levit_reactive.dart', '''
class LxWorker { Future<void> close() async {} }
''');
    newPackage('levit_dart').addFile('lib/levit_dart.dart', '''
class LevitAsyncMap { Future<void> invalidateAll() async {} }
''');
    newPackage('flutter').addFile('lib/widgets.dart', '''
class Widget {}
class State<T extends Widget> {}
class BuildContext { Resolver get levit => Resolver(); }
class Resolver { T find<T>() => throw UnimplementedError(); }
''');
  }
}

@reflectiveTest
class AwaitLifecycleTest extends AnalysisRuleTest with ApiFixtures {
  @override
  void setUp() {
    rule = AwaitLevitLifecycle();
    installApis();
    super.setUp();
  }

  Future<void> test_discardedOrUnawaitedDelegation() async {
    const source = '''
import 'dart:async';
import 'package:levit_dart_core/levit_dart_core.dart';
class Owner extends LevitController {
  @override
  Future<void> onInit() async { super.onInit(); }
  @override
  Future<void> onBeforeClose() async { unawaited(super.onBeforeClose()); }
}
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('super.onInit()'), 'super.onInit()'.length),
      lint(
        source.indexOf('super.onBeforeClose()'),
        'super.onBeforeClose()'.length,
      ),
    ]);
  }

  Future<void> test_awaitReturnAndSynchronousDelegation() async {
    await assertNoDiagnostics('''
import 'package:levit_dart_core/levit_dart_core.dart';
class Owner extends LevitController {
  @override
  Future<void> onInit() async { await (super.onInit()); }
  @override
  Future<void> onBeforeClose() { return super.onBeforeClose(); }
  @override
  void onClose() { super.onClose(); }
}
class Other extends LevitController {
  @override
  Future<void> onBeforeClose() => super.onBeforeClose();
}
''');
  }

  Future<void> test_applicationSuperclassOverride() async {
    const source = '''
import 'package:levit_dart_core/levit_dart_core.dart';
class Base extends LevitController {
  @override
  Future<void> onBeforeClose() async { await super.onBeforeClose(); }
}
class Child extends Base {
  @override
  Future<void> onBeforeClose() async { super.onBeforeClose(); }
}
''';
    await assertDiagnostics(source, [
      lint(
        source.lastIndexOf('super.onBeforeClose()'),
        'super.onBeforeClose()'.length,
      ),
    ]);
  }

  Future<void> test_unrelatedNames() async {
    await assertNoDiagnostics('''
class Other { Future<void> onInit() async {} }
class Child extends Other { Future<void> onInit() async { super.onInit(); } }
''');
  }
}

@reflectiveTest
class GlobalLookupTest extends AnalysisRuleTest with ApiFixtures {
  @override
  void setUp() {
    rule = AvoidGlobalLevitInWidgets();
    installApis();
    super.setUp();
  }

  Future<void> test_widgetAndStateWithImportAlias() async {
    const source = '''
import 'package:levit_dart_core/levit_dart_core.dart' as l;
import 'package:flutter/widgets.dart';
class View extends Widget {
  Object build(BuildContext context) => l.Levit.find<Object>();
}
class ViewState extends State<View> {
  Future<Object> load() => l.Levit.findAsync<Object>();
}
''';
    await assertDiagnostics(source, [
      lint(
        source.indexOf('l.Levit.find<Object>()'),
        'l.Levit.find<Object>()'.length,
      ),
      lint(
        source.indexOf('l.Levit.findAsync<Object>()'),
        'l.Levit.findAsync<Object>()'.length,
      ),
    ]);
  }

  Future<void> test_contextAndNonWidgetComposition() async {
    await assertNoDiagnostics('''
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:flutter/widgets.dart';
Object compose() => Levit.find<Object>();
class View extends Widget {
  Object build(BuildContext context) => context.levit.find<Object>();
}
''');
  }

  Future<void> test_unrelatedLevitAndWidgetNames() async {
    await assertNoDiagnostics('''
class Widget {}
class Levit { static int find() => 1; }
class View extends Widget { int build() => Levit.find(); }
''');
  }
}

@reflectiveTest
class DiscardedFutureTest extends AnalysisRuleTest with ApiFixtures {
  Future<void> test_asyncMapLifecycle() async {
    const source = '''
import 'package:levit_dart/levit_dart.dart';
Future<void> example(LevitAsyncMap m) async {
  m.invalidateAll();
  await m.invalidateAll();
}
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('m.invalidateAll()'), 'm.invalidateAll()'.length),
    ]);
  }

  @override
  void setUp() {
    rule = DiscardedLevitFuture();
    installApis();
    super.setUp();
  }

  Future<void> test_discardedCleanup() async {
    const source = '''
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_reactive/levit_reactive.dart';
void close(LevitScope scope, LxWorker worker) {
  scope.dispose();
  (worker.close());
  Levit.reset();
}
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('scope.dispose()'), 'scope.dispose()'.length),
      lint(source.indexOf('worker.close()'), 'worker.close()'.length),
      lint(source.indexOf('Levit.reset()'), 'Levit.reset()'.length),
    ]);
  }

  Future<void> test_observedFuturesAndUnrelatedMethods() async {
    await assertNoDiagnostics('''
import 'dart:async';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_reactive/levit_reactive.dart';
Future<void> close(LevitScope scope, LxWorker worker) async {
  await scope.dispose();
  final pending = worker.close();
  await pending;
  unawaited(Levit.reset());
}
Future<void> delegate(LxWorker worker) => worker.close();
class Unrelated { Future<void> close() async {} }
void other(Unrelated resource) { resource.close(); }
''');
  }
}
