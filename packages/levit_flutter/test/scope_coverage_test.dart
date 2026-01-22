import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

// Helper class for testing
class TestController {
  final int value;
  TestController(this.value);
}

class TestReactiveController extends LxBase<int> {
  TestReactiveController() : super(0);
  set value(int v) => setValueInternal(v);
}

class TestView extends LScopedView<TestReactiveController> {
  final Function(TestReactiveController) onBuild;
  final bool watch;

  TestView({super.key, required this.onBuild, this.watch = true});

  @override
  TestReactiveController createController() => TestReactiveController();

  @override
  Widget buildContent(BuildContext context, TestReactiveController controller) {
    onBuild(controller);
    return Text('Value: ${controller.value}');
  }

  @override
  bool get autoWatch => watch;
}

void main() {
  group('Levit Flutter Scope Coverage', () {
    testWidgets('LScope creates and disposes scope correctly', (tester) async {
      bool initialized = false;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope<TestController>(
            init: () {
              initialized = true;
              return TestController(42);
            },
            child: Builder(
              builder: (context) {
                final controller = context.levit.find<TestController>();
                return Text('Value: ${controller.value}');
              },
            ),
          ),
        ),
      );

      expect(initialized, true);
      expect(find.text('Value: 42'), findsOneWidget);

      // Verify scope capability via context extension
      final element = tester.element(find.text('Value: 42'));
      expect(element.levit.isRegistered<TestController>(), true);

      // Dispose
      await tester.pumpWidget(Container());

      // Should be disposed (we can't easily check internal scope registry state without exposing it,
      // but verify no crashes and logic execution).
      // If we try to find it via global Levit, it likely won't be there because LScope creates a child scope mostly.
      // But verify that re-mounting creates new instance.

      initialized = false;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope<TestController>(
            init: () {
              initialized = true;
              return TestController(100);
            },
            child: Builder(
              builder: (context) {
                final controller = context.levit.find<TestController>();
                return Text('Value: ${controller.value}');
              },
            ),
          ),
        ),
      );

      expect(initialized, true);
      expect(find.text('Value: 100'), findsOneWidget);
    });

    testWidgets('Nested LScope inheritance', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope<int>(
            init: () => 1,
            child: LScope<String>(
              init: () => 'nested',
              child: Builder(
                builder: (context) {
                  // Should be able to find both
                  final i = context.levit.find<int>();
                  final s = context.levit.find<String>();
                  return Text('$i - $s');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('1 - nested'), findsOneWidget);
    });

    testWidgets('LMultiScope registers multiple bindings', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LMultiScope(
            scopes: [
              LMultiScopeBinding<int>(() => 10),
              LMultiScopeBinding<String>(() => 'multi'),
            ],
            child: Builder(
              builder: (context) {
                final i = context.levit.find<int>();
                final s = context.levit.find<String>();
                return Text('$i $s');
              },
            ),
          ),
        ),
      );

      expect(find.text('10 multi'), findsOneWidget);
    });

    testWidgets('LevitProvider fallback to global', (tester) async {
      // Register global
      Levit.put<double>(() => 3.14);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              final d = context.levit.find<double>();
              final exists = context.levit.isRegistered<double>();
              return Text('Pi: $d, Exists: $exists');
            },
          ),
        ),
      );

      expect(find.text('Pi: 3.14, Exists: true'), findsOneWidget);

      // Cleanup global
      Levit.reset();
    });

    testWidgets('LevitProvider put works in scope', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope<int>(
            init: () => 0,
            child: Builder(
              builder: (context) {
                // Put something into the current scope dynamically
                context.levit.put<String>(() => 'dynamic');
                final s = context.levit.find<String>();
                return Text(s);
              },
            ),
          ),
        ),
      );

      expect(find.text('dynamic'), findsOneWidget);
    });

    testWidgets('LScopedView creates controller and auto-watches',
        (tester) async {
      TestReactiveController? capturedController;
      int buildCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TestView(
            onBuild: (c) {
              capturedController = c;
              buildCount++;
            },
          ),
        ),
      );

      expect(find.text('Value: 0'), findsOneWidget);
      expect(buildCount, 1);

      // Verify reactive update triggers rebuild
      capturedController!.value = 5;
      await tester.pump(); // LWatch triggers setState

      expect(find.text('Value: 5'), findsOneWidget);
      expect(buildCount, 2);
    });

    testWidgets('LScopedView without auto-watch', (tester) async {
      TestReactiveController? capturedController;
      int buildCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TestView(
            watch: false,
            onBuild: (c) {
              capturedController = c;
              buildCount++;
            },
          ),
        ),
      );

      expect(find.text('Value: 0'), findsOneWidget);
      expect(buildCount, 1);

      // Verify reactive update DOES NOT trigger rebuild
      capturedController!.value = 5;
      await tester.pump();

      expect(find.text('Value: 0'),
          findsOneWidget); // Text widget didn't rebuild/update
      expect(buildCount, 1);
    });

    testWidgets('LScope update warning check', (tester) async {
      // This test mainly just covers the `update` method logic path.
      // We're not asserting the console output but ensuring no crashes when props change.

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope<int>(
            key: ValueKey('scope'),
            init: () => 1,
            tag: 'tag1',
            child: Container(),
          ),
        ),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope<int>(
            key: ValueKey('scope'), // Same key to force update
            init: () => 1,
            tag: 'tag2', // Changed tag
            child: Container(),
          ),
        ),
      );

      // Succeeded if no exception throw
    });
  });
}
