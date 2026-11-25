import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('fresh async resolver closures do not refetch without args', (
    tester,
  ) async {
    var resolutions = 0;
    Widget stage(String label) => MaterialApp(
      home: LAsyncView<String>(
        resolver: (_) async {
          resolutions++;
          return label;
        },
        builder: (_, value) => Text(value),
      ),
    );
    await tester.pumpWidget(stage('first'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(stage('second'));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
    expect(resolutions, 1);
  });
}
