import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('LView renders orElse when controller is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LView<String>(
          resolver: (context) => null, // Explicitly return null
          orElse: (context) => const Text('Fallback UI'),
          builder: (context, controller) => Text('Success: $controller'),
        ),
      ),
    );

    expect(find.text('Fallback UI'), findsOneWidget);
    expect(find.text('Success'), findsNothing);
  });
}
