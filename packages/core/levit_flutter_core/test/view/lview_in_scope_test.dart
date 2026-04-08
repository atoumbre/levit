import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class _TestService {}

void main() {
  testWidgets('LView in Scope', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: LScope(
            dependencyFactory: (s) => s.put<_TestService>(() => _TestService()),
            child: LView<_TestService>(
                resolver: (context) => context.levit.find<_TestService>(),
                builder: (context, controller) =>
                    const Text('Controller Found')))));
    expect(find.text('Controller Found'), findsOneWidget);
  });
}
