import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';
import '../helpers.dart';

void main() {
  testWidgets('LView.put registers and resolves', (tester) async {
    Levit.reset(force: true);
    await tester.pumpWidget(MaterialApp(
        home: LView<TestController>.put(() => TestController()..count = 42,
            builder: (context, controller) =>
                Text('Count: ${controller.count}'))));
    expect(find.text('Count: 42'), findsOneWidget);
  });
  testWidgets('LView constructor resolves existing', (tester) async {
    Levit.reset(force: true);
    Levit.put(() => TestController()..count = 100);
    await tester.pumpWidget(MaterialApp(
        home: LView<TestController>(
            builder: (context, controller) =>
                Text('Count: ${controller.count}'))));
    expect(find.text('Count: 100'), findsOneWidget);
  });
}
