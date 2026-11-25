import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class CounterController extends LevitController {
  final count = 0.lx;
  void increment() => count.value++;
}

void main() {
  testWidgets('documented Flutter bootstrap and scoped counter', (
    tester,
  ) async {
    Levit.enableAutoLinking();
    late CounterController controller;
    await tester.pumpWidget(
      MaterialApp(
        home: LScopedView<CounterController>.put(
          () => controller = CounterController(),
          builder: (context, value) => TextButton(
            onPressed: value.increment,
            child: Text('${value.count()}'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.disposed;
    expect(controller.count.isDisposed, isTrue);
    Levit.disableAutoLinking();
  });
}
