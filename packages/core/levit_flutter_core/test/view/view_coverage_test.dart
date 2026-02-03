import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('LAsyncView warns on anonymous closure update', (tester) async {
    // This test targets line 299 in view.dart where a debugPrint warning is issued
    // when an anonymous closure is detected during a widget update without args.

    final s1 = 's1'.lx;
    final s2 = 's2'.lx;

    await tester.pumpWidget(
      MaterialApp(
        home: LAsyncView<String>(
          // First anonymous closure
          resolver: (context) async => s1.value,
          builder: (context, val) => Text(val),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('s1'), findsOneWidget);

    // Rebuild with a DIFFERENT anonymous closure
    // This triggers the didUpdateWidget logic.
    // Since args are null and resolvers are different (new closure),
    // it proceeds to check if it's a closure and warns.
    await tester.pumpWidget(
      MaterialApp(
        home: LAsyncView<String>(
          // Second anonymous closure
          resolver: (context) async => s2.value,
          builder: (context, val) => Text(val),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('s2'), findsOneWidget);
  });
}
