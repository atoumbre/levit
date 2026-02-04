import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

// Helper class for testing
class TestController {
  final int value;
  TestController(this.value);
}

class TestReactiveController extends LxVar<int> {
  TestReactiveController() : super(0);
}

class TestView extends StatelessWidget {
  final Function(TestReactiveController) onBuild;
  final bool watch;

  const TestView({super.key, required this.onBuild, this.watch = true});

  @override
  Widget build(BuildContext context) {
    return LScopedView<TestReactiveController>(
      autoWatch: watch,
      dependencyFactory: (s) =>
          s.put<TestReactiveController>(() => TestReactiveController()),
      resolver: (context) => context.levit.find<TestReactiveController>(),
      builder: (context, controller) {
        onBuild(controller);
        return Text('Value: ${controller.value}');
      },
    );
  }
}

void main() {
  group('Levit Flutter Scope Coverage', () {
    testWidgets('LScope creates and disposes scope correctly', (tester) async {
      bool initialized = false;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            dependencyFactory: (s) =>
                s.put<TestController>(() => TestController(42)),
            child: Builder(
              builder: (context) {
                initialized = true;
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

      initialized = false;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            dependencyFactory: (s) =>
                s.put<TestController>(() => TestController(100)),
            child: Builder(
              builder: (context) {
                initialized = true;
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
          child: LScope(
            dependencyFactory: (s) => s.put<int>(() => 1),
            child: LScope(
              dependencyFactory: (s) => s.put<String>(() => 'nested'),
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

    testWidgets('LScope registers multiple bindings', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            dependencyFactory: (s) {
              s.put<int>(() => 10);
              s.put<String>(() => 'multi');
            },
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
          child: LScope(
            dependencyFactory: (s) => s.put<int>(() => 0),
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

    testWidgets('LScope update coverage', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            key: const ValueKey('scope'),
            dependencyFactory: (s) => s.put<int>(() => 1, tag: 'tag1'),
            child: Container(),
          ),
        ),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            key: const ValueKey('scope'), // Same key to force update
            dependencyFactory: (s) => s.put<int>(() => 1, tag: 'tag2'),
            child: Container(),
          ),
        ),
      );
    });
  });
}
