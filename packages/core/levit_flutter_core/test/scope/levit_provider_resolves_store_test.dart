import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('LevitProvider resolves LevitStore using context.levit.find',
      (tester) async {
    final store = LevitStore<String>((ref) => 'store_value');
    String? resolvedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: LScope(
          child: Builder(
            builder: (context) {
              // This calls LevitProvider.find with key: store
              resolvedValue = context.levit.find<String>(key: store);
              return Text(resolvedValue ?? 'null');
            },
          ),
        ),
      ),
    );

    expect(resolvedValue, 'store_value');
    expect(find.text('store_value'), findsOneWidget);
  });
}
