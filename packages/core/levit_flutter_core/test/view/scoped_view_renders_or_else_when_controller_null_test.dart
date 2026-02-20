import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('LScopedView renders orElse when controller is null',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LScopedView<String>(
          // No dependency factory, so context.levit.findOrNull<String>() returns null
          orElse: (context) => const Text('Scoped Fallback UI'),
          builder: (context, controller) => Text('Success: $controller'),
        ),
      ),
    );

    expect(find.text('Scoped Fallback UI'), findsOneWidget);
    expect(find.text('Success'), findsNothing);
  });
}
