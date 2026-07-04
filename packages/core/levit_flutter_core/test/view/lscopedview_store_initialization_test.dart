import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('LScopedView.store coverage', (tester) async {
    final state = LevitStore((ref) => 'scoped_val');
    await tester.pumpWidget(MaterialApp(
        home: LScopedView.store(state,
            builder: (context, value) => Text(value))));
    expect(find.text('scoped_val'), findsOneWidget);
  });
}
