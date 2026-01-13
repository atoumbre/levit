import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  group('Stress Test: LStatusBuilder', () {
    testWidgets('State Switch - 1000 status transitions', (tester) async {
      print('[Description] Tests LStatusBuilder state switching performance.');
      final status = LxFuture(Future.value(0));

      await tester.pumpWidget(MaterialApp(
        home: LStatusBuilder<int>(
          source: status,
          onSuccess: (data) => Text('Success: $data'),
          onWaiting: () => const Text('Waiting'),
          onError: (error, _) => Text('Error: $error'),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('Success: 0'), findsOneWidget);

      const transitions = 1000;
      final sw = Stopwatch()..start();
      for (var i = 0; i < transitions; i++) {
        status.restart(Future.value(i));
        // Skip pump on every iteration to avoid test timeout
        if (i % 100 == 0) {
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();
      sw.stop();

      print(
          'LStatusBuilder State Switch: $transitions transitions in ${sw.elapsedMilliseconds}ms');

      status.close();
    });

    testWidgets('Flood - 500 LStatusBuilder widgets', (tester) async {
      print(
          '[Description] Tests many LStatusBuilder widgets in a single frame.');
      const widgetCount = 500;
      final statuses =
          List.generate(widgetCount, (_) => LxFuture(Future.value(0)));

      await tester.pumpWidget(MaterialApp(
        home: ListView.builder(
          itemCount: widgetCount,
          itemBuilder: (context, index) {
            return LStatusBuilder<int>(
              source: statuses[index],
              onSuccess: (data) => Text('S$index'),
              onWaiting: () => const Text('Waiting'),
              onError: (error, _) => const Text('Error'),
            );
          },
        ),
      ));

      await tester.pumpAndSettle();

      // Update all to trigger rebuild
      final sw = Stopwatch()..start();
      for (var i = 0; i < widgetCount; i++) {
        statuses[i].restart(Future.value(i + 1));
      }
      await tester.pumpAndSettle();
      sw.stop();

      print(
          'LStatusBuilder Flood: $widgetCount widgets updated in ${sw.elapsedMilliseconds}ms');

      for (final s in statuses) {
        s.close();
      }
    });
  });
}
