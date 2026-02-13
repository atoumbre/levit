import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class TestController extends LevitController {
  final String label;
  TestController(this.label);
}

void main() {
  testWidgets('LView re-resolves controller when args change', (tester) async {
    final controller1 = TestController('One');
    final controller2 = TestController('Two');

    // We'll use a stateful parent to trigger updates
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            children: [
              LView<TestController>(
                // Resolver that captures local state to simulate change
                resolver: (context) => (tester.takeException() == null)
                    ? controller1
                    : controller2, // This is a bit hacky, let's just use a key change or parent state
                builder: (context, c) => Text(c.label),
              ),
              ElevatedButton(
                onPressed: () => setState(() {}),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    ));

    // Actually, LView is stateful. To trigger didUpdateWidget, we need to rebuild the parent
    // AND have the LView widget itself be "new" but at the same location.

    Widget buildStage(TestController controller) {
      return MaterialApp(
        home: Scaffold(
          body: LView<TestController>(
            resolver: (_) => controller,
            args: [controller],
            builder: (_, c) => Text(c.label),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildStage(controller1));
    expect(find.text('One'), findsOneWidget);

    // Trigger didUpdateWidget by pumping a new widget instance with different resolver result
    await tester.pumpWidget(buildStage(controller2));
    expect(find.text('Two'), findsOneWidget);
  });

  testWidgets('LView does not re-resolve controller without args',
      (tester) async {
    final controller1 = TestController('One');
    final controller2 = TestController('Two');

    Widget buildStage(TestController controller) {
      return MaterialApp(
        home: Scaffold(
          body: LView<TestController>(
            resolver: (_) => controller,
            builder: (_, c) => Text(c.label),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildStage(controller1));
    expect(find.text('One'), findsOneWidget);

    await tester.pumpWidget(buildStage(controller2));
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsNothing);
  });

  testWidgets('LView re-resolves when inherited scope changes', (tester) async {
    Widget buildStage(int arg) {
      return MaterialApp(
        home: LScope(
          args: [arg],
          child: LView<int>(
            resolver: (context) => LScope.of(context)!.id,
            builder: (_, id) => Text('scope:$id'),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildStage(1));
    final firstText = tester.widget<Text>(find.byType(Text)).data!;

    await tester.pumpWidget(buildStage(2));
    final secondText = tester.widget<Text>(find.byType(Text)).data!;

    expect(secondText, isNot(equals(firstText)));
  });

  testWidgets('LAsyncView re-resolves when inherited scope changes',
      (tester) async {
    Widget buildStage(int arg) {
      return MaterialApp(
        home: LScope(
          args: [arg],
          child: LAsyncView<int>(
            resolver: (context) async => LScope.of(context)!.id,
            builder: (_, id) => Text('async-scope:$id'),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildStage(1));
    await tester.pumpAndSettle();
    final firstText = tester.widget<Text>(find.byType(Text)).data!;

    await tester.pumpWidget(buildStage(2));
    await tester.pumpAndSettle();
    final secondText = tester.widget<Text>(find.byType(Text)).data!;

    expect(secondText, isNot(equals(firstText)));
  });
}
