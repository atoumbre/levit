import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class TestController extends LevitController {
  final count = 0.lx;
}

void main() {
  testWidgets('LAsyncScope + LView supports autoWatch: false', (tester) async {
    final controller = TestController();

    await tester.pumpWidget(MaterialApp(
      home: LAsyncScope(
        dependencyFactory: (scope) async {
          await Future.delayed(const Duration(milliseconds: 10));
          scope.put(() => controller);
        },
        loading: (_) => const Text('Loading...'),
        child: LView<TestController>(
          autoWatch: false,
          builder: (context, c) => Text('Count: ${c.count.value}'),
        ),
      ),
    ));

    // Wait for async init
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Count: 0'), findsOneWidget);

    // Update reactive value
    controller.count.value++;
    await tester.pump();

    // Should NOT rebuild because autoWatch is false
    expect(find.text('Count: 0'), findsOneWidget);
  });
}
