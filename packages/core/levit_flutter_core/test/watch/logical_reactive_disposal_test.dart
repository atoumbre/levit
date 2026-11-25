import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets(
    'LWatch replaces disposed logical reactive in multi-dependency builds',
    (tester) async {
      final anchor = 0.lx.named('anchor').ownedBy('owner:multi');
      var target = 'first'.lx.named('target').ownedBy('owner:multi');

      await tester.pumpWidget(
        MaterialApp(
          home: LWatch(() => Text('${anchor.value}:${target.value}')),
        ),
      );

      expect(find.text('0:first'), findsOneWidget);

      await target.close();
      target = 'second'.lx.named('target').ownedBy('owner:multi');
      anchor.value = 1;
      await tester.pump();

      expect(find.text('1:second'), findsOneWidget);

      target.value = 'third';
      await tester.pump();
      expect(find.text('1:third'), findsOneWidget);

      await anchor.close();
      await target.close();
    },
  );
}
