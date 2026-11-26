// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:levit_lints/src/rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RedundantOuterLWatchTest);
    defineReflectiveTests(UnscopedOverlayTest);
  });
}

mixin FlutterRuleFixtures on AnalysisRuleTest {
  void installFlutterApis() {
    newPackage('flutter').addFile('lib/widgets.dart', '''
class Widget { const Widget(); }
class StatelessWidget extends Widget { const StatelessWidget(); }
class State<T extends Widget> {}
class BuildContext {}
class Text extends Widget { const Text(String data); }
class Scaffold extends Widget { const Scaffold({Widget? body}); }
''');
    newPackage('flutter').addFile('lib/material.dart', '''
export 'widgets.dart';
import 'widgets.dart';

Future<T?> showDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
}) async => null;

Future<T?> showModalBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
}) async => null;
''');
    newPackage('levit_flutter_core').addFile('lib/levit_flutter_core.dart', '''
import 'package:flutter/widgets.dart';

class LWatch extends Widget {
  const LWatch(Widget Function() builder);
}

class LScope extends Widget {
  const LScope({required Widget child});
  static Widget capture(BuildContext context, {required Widget child}) => child;
}

class LView<T> extends Widget {
  const LView({
    Widget Function(BuildContext context, T controller)? builder,
    bool autoWatch = true,
  });
  Widget buildView(BuildContext context, T controller) => const Text('');
}

class LScopedView<T> extends LView<T> {
  const LScopedView({
    super.builder,
    super.autoWatch = true,
  });
  factory LScopedView.put(
    T Function() create, {
    required Widget Function(BuildContext context, T controller) builder,
    bool autoWatch = true,
  }) => LScopedView<T>(builder: builder, autoWatch: autoWatch);
}

class LAsyncView<T> extends Widget {
  const LAsyncView({
    Widget Function(BuildContext context, T controller)? builder,
    bool autoWatch = true,
  });
  Widget buildView(BuildContext context, T controller) => const Text('');
}
''');
    newPackage('levit_flutter').addFile('lib/levit_flutter.dart', '''
export 'package:levit_flutter_core/levit_flutter_core.dart';
import 'package:flutter/widgets.dart';

Future<T?> showLevitDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
}) async => null;

Future<T?> showLevitModalBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
}) async => null;
''');
  }
}

@reflectiveTest
class RedundantOuterLWatchTest extends AnalysisRuleTest
    with FlutterRuleFixtures {
  @override
  void setUp() {
    rule = AvoidRedundantOuterLWatch();
    installFlutterApis();
    super.setUp();
  }

  Future<void> test_flagsOuterLWatchInBuilderAndSubclass() async {
    const source = '''
import 'package:flutter/widgets.dart';
import 'package:levit_flutter/levit_flutter.dart';

Widget buildInline() {
  return LScopedView<int>.put(
    () => 1,
    builder: (context, value) => LWatch(() => const Text('x')),
  );
}

class BadView extends LView<int> {
  const BadView();

  @override
  Widget buildView(BuildContext context, int controller) {
    return LWatch(() => const Text('y'));
  }
}
''';
    await assertDiagnostics(source, [
      lint(
        source.indexOf("LWatch(() => const Text('x'))"),
        "LWatch(() => const Text('x'))".length,
      ),
      lint(
        source.indexOf("LWatch(() => const Text('y'))"),
        "LWatch(() => const Text('y'))".length,
      ),
    ]);
  }

  Future<void> test_allowsAutoWatchFalseAndNestedLWatch() async {
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';
import 'package:levit_flutter/levit_flutter.dart';

Widget buildNested() {
  return LScopedView<int>.put(
    () => 1,
    builder: (context, value) => Scaffold(
      body: LWatch(() => const Text('nested')),
    ),
  );
}

Widget buildManual() {
  return LView<int>(
    autoWatch: false,
    builder: (context, value) => LWatch(() => const Text('manual')),
  );
}

class ManualView extends LView<int> {
  const ManualView() : super(autoWatch: false);

  @override
  Widget buildView(BuildContext context, int controller) {
    return LWatch(() => const Text('manual subclass'));
  }
}

class DynamicView extends LView<int> {
  const DynamicView({super.autoWatch});

  @override
  Widget buildView(BuildContext context, int controller) {
    return LWatch(() => const Text('dynamic'));
  }
}
''');
  }
}

@reflectiveTest
class UnscopedOverlayTest extends AnalysisRuleTest with FlutterRuleFixtures {
  @override
  void setUp() {
    rule = AvoidUnscopedOverlay();
    installFlutterApis();
    super.setUp();
  }

  Future<void> test_flagsRawDialogAndBottomSheetInLevitWidgets() async {
    const source = '''
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

class Page extends LView<int> {
  const Page();

  void open(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const Text('dialog'),
    );
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => const Text('sheet'),
    );
  }
}
''';
    await assertDiagnostics(source, [
      lint(
        source.indexOf('showDialog<void>'),
        "showDialog<void>(\n      context: context,\n      builder: (ctx) => const Text('dialog'),\n    )"
            .length,
      ),
      lint(
        source.indexOf('showModalBottomSheet<void>'),
        "showModalBottomSheet<void>(\n      context: context,\n      builder: (ctx) => const Text('sheet'),\n    )"
            .length,
      ),
    ]);
  }

  Future<void> test_allowsLevitHelpersCapturedScopeAndNonLevitFiles() async {
    await assertNoDiagnostics('''
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

class Page extends StatelessWidget {
  Widget wrap(Widget child) => child;

  void open(BuildContext context) {
    showLevitDialog<void>(
      context: context,
      builder: (ctx) => const Text('dialog'),
    );
    showLevitModalBottomSheet<void>(
      context: context,
      builder: (ctx) => const Text('sheet'),
    );
    showDialog<void>(
      context: context,
      builder: (ctx) =>
          wrap(LScope.capture(context, child: const Text('captured'))),
    );
  }
}
''');
  }

  Future<void> test_ignoresFilesWithoutLevitFlutterImport() async {
    await assertNoDiagnostics('''
import 'package:flutter/material.dart';

class PlainPage extends StatelessWidget {
  void open(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const Text('plain'),
    );
  }
}
''');
  }
}
