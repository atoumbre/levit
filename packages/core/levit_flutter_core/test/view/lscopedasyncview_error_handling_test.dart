import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('LAsyncScopedView handles error state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LAsyncScopedView<String>.put(
          () async {
            await Future.delayed(const Duration(milliseconds: 10));
            throw Exception('Test Error');
          },
          error: (context, error) => Text('Error: $error'),
          builder: (context, controller) => const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Test Error'), findsOneWidget);
  });
}
