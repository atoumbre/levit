import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';
import '../helpers.dart';

void main() {
  testWidgets('LScopedView.put works with tags and isolation', (tester) async {
    Levit.reset(force: true);
    await tester.pumpWidget(MaterialApp(
        home: LScopedView<TestController>.put(
            () => TestController()..count = 42,
            tag: 'scoped',
            builder: (context, controller) =>
                Text('Count: ${controller.count}'))));
    expect(find.text('Count: 42'), findsOneWidget);
    expect(() => Levit.find<TestController>(tag: 'scoped'), throwsException);
  });
}
