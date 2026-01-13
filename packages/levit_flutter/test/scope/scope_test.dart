import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../helpers.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('LScope', () {
    testWidgets('registers controller in local scope', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LScope<TestController>(
            init: () => TestController(),
            child: Builder(
              builder: (context) {
                return Text(
                    'Registered: ${context.levit.isRegistered<TestController>()}');
              },
            ),
          ),
        ),
      );

      expect(find.text('Registered: true'), findsOneWidget);
      expect(Levit.isRegistered<TestController>(), isFalse);
    });

    testWidgets('deletes controller on dispose', (tester) async {
      final showScope = ValueNotifier(true);
      TestController? controller;

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: showScope,
            builder: (context, show, __) => show
                ? LScope<TestController>(
                    init: () {
                      controller = TestController();
                      return controller!;
                    },
                    child: Builder(builder: (context) {
                      return Text(
                          'Registered: ${context.levit.isRegistered<TestController>()}');
                    }),
                  )
                : const Text('Hidden'),
          ),
        ),
      );

      expect(find.text('Registered: true'), findsOneWidget);
      expect(controller?.closeCalled, isFalse);

      showScope.value = false;
      await tester.pump();

      expect(find.text('Hidden'), findsOneWidget);
      expect(controller?.closeCalled, isTrue);
    });

    testWidgets('controller accessible via context.levit.find', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LScope<TestController>(
            init: () => TestController(),
            child: Builder(
              builder: (context) {
                final controller = context.levit.find<TestController>();
                return Text('Count: ${controller.count}');
              },
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('supports tags locally', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              LScope<TestController>(
                init: () => TestController()..count = 1,
                tag: 'first',
                child: Builder(builder: (context) {
                  return Text(
                      'First: ${context.levit.find<TestController>(tag: 'first').count}');
                }),
              ),
              LScope<TestController>(
                init: () => TestController()..count = 2,
                tag: 'second',
                child: Builder(builder: (context) {
                  return Text(
                      'Second: ${context.levit.find<TestController>(tag: 'second').count}');
                }),
              ),
            ],
          ),
        ),
      );

      expect(find.text('First: 1'), findsOneWidget);
      expect(find.text('Second: 2'), findsOneWidget);
    });

    testWidgets('nests inside LScope (parentScope usage)', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: LScope<TestController>(
          init: () => TestController(),
          child: LScope<TestController>(
            name: 'nested',
            init: () => TestController(),
            child: Builder(builder: (c) {
              return Text('Nested: ${c.levit.isRegistered<TestController>()}');
            }),
          ),
        ),
      ));

      expect(find.text('Nested: true'), findsOneWidget);
    });

    testWidgets('LevContext.put works with scope', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: LScope<TestController>(
          init: () => TestController(),
          child: Builder(
            builder: (c) {
              final ctrl = TestController();
              c.levit.put<TestController>(() => ctrl, tag: 'dynamic');
              final found = c.levit.find<TestController>(tag: 'dynamic');
              return Text('Found: ${found == ctrl}');
            },
          ),
        ),
      ));
      expect(find.text('Found: true'), findsOneWidget);
    });

    testWidgets('updateShouldNotify detects scope changes', (tester) async {
      final rebuildTrigger = ValueNotifier<int>(0);

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<int>(
          valueListenable: rebuildTrigger,
          builder: (context, value, _) {
            return LScope<TestController>(
              key: const ValueKey('scope'),
              init: () => TestController(),
              child: Builder(builder: (c) {
                final registered = c.levit.isRegistered<TestController>();
                return Text('Found: $registered, build: $value');
              }),
            );
          },
        ),
      ));

      expect(find.text('Found: true, build: 0'), findsOneWidget);

      rebuildTrigger.value = 1;
      await tester.pump();

      expect(find.text('Found: true, build: 1'), findsOneWidget);
    });
  });

  group('LMultiScope', () {
    testWidgets('registers multiple controllers locally', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LMultiScope(
            scopes: [
              LMultiScopeBinding<TestController>(
                  () => TestController()..count = 1),
              LMultiScopeBinding<AnotherController>(
                  () => AnotherController()..name = 'Test'),
            ],
            child: Builder(
              builder: (context) {
                final test = context.levit.find<TestController>();
                final another = context.levit.find<AnotherController>();
                return Text('${test.count} - ${another.name}');
              },
            ),
          ),
        ),
      );

      expect(find.text('1 - Test'), findsOneWidget);
    });

    testWidgets('nests inside LScope', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: LScope<TestController>(
          init: () => TestController(),
          child: LMultiScope(
            scopes: [
              LMultiScopeBinding<TestController>(() => TestController())
            ],
            child: Container(),
          ),
        ),
      ));
      expect(find.byType(LMultiScope), findsOneWidget);
    });
  });

  group('LScopedView', () {
    testWidgets('creates and provides controller', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: TestScopedView()),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('disposes controller on widget removal', (tester) async {
      final showWidget = ValueNotifier(true);
      TestController? controller;

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: showWidget,
            builder: (context, show, __) => show
                ? CaptureScopedView(onController: (c) => controller = c)
                : const Text('Hidden'),
          ),
        ),
      );

      expect(find.text('Captured: 0'), findsOneWidget);
      expect(controller?.closeCalled, isFalse);

      showWidget.value = false;
      await tester.pump();

      expect(find.text('Hidden'), findsOneWidget);
      expect(controller?.closeCalled, isTrue);
    });

    testWidgets('controller accessible in scope', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TestScopedView(),
        ),
      );

      // The controller should be registered in the scope
      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('supports tags', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: TaggedScopedView()),
      );

      expect(find.text('Tagged: 0'), findsOneWidget);
    });

    testWidgets('autoWatch enables reactive updates', (tester) async {
      late TestController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: AutoWatchScopedView(onController: (c) => controller = c),
        ),
      );

      expect(find.text('Reactive: 0'), findsOneWidget);

      controller.reactiveCount.value = 42;
      await tester.pump();

      expect(find.text('Reactive: 42'), findsOneWidget);
    });

    testWidgets('autoWatch false disables reactive updates', (tester) async {
      late TestController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: NoAutoWatchScopedView(onController: (c) => controller = c),
        ),
      );

      expect(find.text('NoWatch: 0'), findsOneWidget);

      controller.reactiveCount.value = 42;
      await tester.pump();

      // Should NOT update since autoWatch is false
      expect(find.text('NoWatch: 0'), findsOneWidget);
    });

    testWidgets('nests inside LScope', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope<AnotherController>(
            init: () => AnotherController()..name = 'Parent',
            child: TestScopedView(),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('nests inside another LScopedView', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: OuterScopedView(),
        ),
      );

      expect(find.text('Outer: 1, Inner: 2'), findsOneWidget);
    });
  });
}

// Test helpers for LScopedView

class TestScopedView extends LScopedView<TestController> {
  @override
  TestController createController() => TestController();

  @override
  Widget buildContent(BuildContext context, TestController controller) {
    return Text('Count: ${controller.count}');
  }
}

class CaptureScopedView extends LScopedView<TestController> {
  final void Function(TestController) onController;

  const CaptureScopedView({super.key, required this.onController});

  @override
  TestController createController() => TestController();

  @override
  Widget buildContent(BuildContext context, TestController controller) {
    onController(controller);
    return Text('Captured: ${controller.count}');
  }
}

class TaggedScopedView extends LScopedView<TestController> {
  @override
  String? get tag => 'special';

  @override
  TestController createController() => TestController();

  @override
  Widget buildContent(BuildContext context, TestController controller) {
    return Text('Tagged: ${controller.count}');
  }
}

class AutoWatchScopedView extends LScopedView<TestController> {
  final void Function(TestController) onController;

  const AutoWatchScopedView({super.key, required this.onController});

  @override
  TestController createController() => TestController();

  @override
  Widget buildContent(BuildContext context, TestController controller) {
    onController(controller);
    return Text('Reactive: ${controller.reactiveCount.value}');
  }
}

class NoAutoWatchScopedView extends LScopedView<TestController> {
  final void Function(TestController) onController;

  const NoAutoWatchScopedView({super.key, required this.onController});

  @override
  bool get autoWatch => false;

  @override
  TestController createController() => TestController();

  @override
  Widget buildContent(BuildContext context, TestController controller) {
    onController(controller);
    return Text('NoWatch: ${controller.reactiveCount.value}');
  }
}

class OuterScopedView extends LScopedView<TestController> {
  @override
  TestController createController() => TestController()..count = 1;

  @override
  Widget buildContent(BuildContext context, TestController controller) {
    return InnerScopedView(outerCount: controller.count);
  }
}

class InnerScopedView extends LScopedView<AnotherController> {
  final int outerCount;

  const InnerScopedView({super.key, required this.outerCount});

  @override
  AnotherController createController() => AnotherController()..name = '2';

  @override
  Widget buildContent(BuildContext context, AnotherController controller) {
    return Text('Outer: $outerCount, Inner: ${controller.name}');
  }
}
