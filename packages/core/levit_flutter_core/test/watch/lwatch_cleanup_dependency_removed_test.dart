import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('LWatch cleans up subscriptions', (tester) async {
    final notifier = 0.lx;
    final toggle = true.lx;
    await tester.pumpWidget(MaterialApp(
        home: LWatch(() => toggle.value
            ? Text('V: ${notifier.value}')
            : const Text('V: Clean'))));
    expect(find.text('V: 0'), findsOneWidget);
    toggle.value = false;
    await tester.pump();
    expect(find.text('V: Clean'), findsOneWidget);
  });
}
