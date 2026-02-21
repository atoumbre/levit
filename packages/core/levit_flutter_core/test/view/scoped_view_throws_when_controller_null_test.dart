import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets(
      'LScopedView throws StateError when controller is null and no orElse provided',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LScopedView<String>(
          builder: (context, controller) => Text('Success: $controller'),
        ),
      ),
    );

    expect(tester.takeException(), isInstanceOf<StateError>());
  });
}
