import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';
import '../helpers.dart';

void main() {
  testWidgets('LScope.put static factory', (tester) async {
    await tester.pumpWidget(LScope.put<TestController>(
        () => TestController()..count = 123,
        child: MaterialApp(
            home: Builder(
                builder: (context) => Text(
                    'Count: ${context.levit.find<TestController>().count}')))));
    expect(find.text('Count: 123'), findsOneWidget);
  });
}
