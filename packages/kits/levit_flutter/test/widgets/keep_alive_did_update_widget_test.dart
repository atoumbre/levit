import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  testWidgets('LKeepAlive didUpdateWidget triggers properly', (tester) async {
    bool keepAlive = true;
    await tester.pumpWidget(
        MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      return Column(children: [
        LKeepAlive(keepAlive: keepAlive, child: const Text('keep')),
        TextButton(
            onPressed: () => setState(() => keepAlive = !keepAlive),
            child: const Text('toggle'))
      ]);
    })));
    expect(find.text('keep'), findsOneWidget);
    await tester.tap(find.text('toggle'));
    await tester.pump();
  });
}
