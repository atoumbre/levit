import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

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
      dependencyFactory: (s) => s.put<TestReactiveController>(() => TestReactiveController()),
      resolver: (context) => context.levit.find<TestReactiveController>(),
      builder: (context, controller) {
        onBuild(controller);
        return Text('Value: ${controller.value}');
      },
    );
  }
}

void main() {
  group('LScopedView Behavior', () {
    testWidgets('LScopedView creates controller and auto-watches', (tester) async {
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

      capturedController!.value = 5;
      await tester.pump();

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

      capturedController!.value = 5;
      await tester.pump();

      expect(find.text('Value: 0'), findsOneWidget);
      expect(buildCount, 1);
    });
  });
}
