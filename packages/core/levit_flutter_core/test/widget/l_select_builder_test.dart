import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('LSelectorBuilder builds with initial value', (tester) async {
    final count = 2.lx;
    await tester.pumpWidget(
      MaterialApp(
        home: LSelectorBuilder<int>(
          () => count.value * 2,
          (value) => Text('Value: $value'),
        ),
      ),
    );

    expect(find.text('Value: 4'), findsOneWidget);
  });

  testWidgets('LSelectorBuilder updates when dependency changes',
      (tester) async {
    final count = 2.lx;
    await tester.pumpWidget(
      MaterialApp(
        home: LSelectorBuilder<int>(
          () => count.value * 2,
          (value) => Text('Value: $value'),
        ),
      ),
    );

    expect(find.text('Value: 4'), findsOneWidget);

    count.value = 3;
    await tester.pump();

    expect(find.text('Value: 6'), findsOneWidget);
  });

  testWidgets('LSelectorBuilder updates when builder function changes',
      (tester) async {
    final count = 2.lx;
    await tester.pumpWidget(
      MaterialApp(
        home: LSelectorBuilder<int>(
          () => count.value * 2,
          (value) => Text('Value: $value'),
        ),
      ),
    );

    expect(find.text('Value: 4'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: LSelectorBuilder<int>(
          () => count.value * 3, // Changed logic
          (value) => Text('Value: $value'),
        ),
      ),
    );

    expect(find.text('Value: 6'), findsOneWidget);

    count.value = 3;
    await tester.pump();
    expect(find.text('Value: 9'), findsOneWidget);
  });

  testWidgets('LSelectorBuilder disposes inline LxComputed', (tester) async {
    final count = 0.lx;
    // We can't easily check if an internal LxComputed is disposed without exposing it or mocking.
    // However, we can check if listeners are removed from dependencies.

    expect(count.hasListener, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: LSelectorBuilder<int>(
          () => count.value,
          (value) => Text('Value: $value'),
        ),
      ),
    );

    expect(count.hasListener, isTrue);

    await tester.pumpWidget(const SizedBox());

    expect(count.hasListener, isFalse);
  });
}
