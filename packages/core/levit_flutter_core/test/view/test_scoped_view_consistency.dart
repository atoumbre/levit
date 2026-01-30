import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

import '../helpers.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('API Symmetry - .put with tags', () {
    testWidgets('LScopedView.put respects tags', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LScopedView<TestController>.put(
            () => TestController()..count = 42,
            tag: 'my-tag',
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
          ),
        ),
      );

      expect(find.text('Count: 42'), findsOneWidget);
    });
  });
}
