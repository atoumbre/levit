import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class TestReactive<T> extends LxVar<T> {
  TestReactive(super.initial);
}

void main() {
  group('LWatch Dependency Tracking', () {
    testWidgets('LWatch auto-tracks dependencies', (tester) async {
      final rx = TestReactive<int>(0);
      int buildCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LWatch(() {
            buildCount++;
            return Text('Value: ${rx.value}');
          }),
        ),
      );

      expect(find.text('Value: 0'), findsOneWidget);
      expect(buildCount, 1);

      rx.value = 1;
      await tester.pump();

      expect(find.text('Value: 1'), findsOneWidget);
      expect(buildCount, 2);
    });

    testWidgets('LWatch handles multiple dependencies (Fast Path -> Slow Path)',
        (tester) async {
      final rx1 = TestReactive<int>(0);
      final rx2 = TestReactive<int>(10);
      int buildCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LWatch(() {
            buildCount++;
            return Text('${rx1.value} - ${rx2.value}');
          }),
        ),
      );

      expect(find.text('0 - 10'), findsOneWidget);
      expect(buildCount, 1);

      rx1.value = 1;
      await tester.pump();
      expect(find.text('1 - 10'), findsOneWidget);
      expect(buildCount, 2);

      rx2.value = 20;
      await tester.pump();
      expect(find.text('1 - 20'), findsOneWidget);
      expect(buildCount, 3);
    });

    testWidgets('LWatch cleanup on dependencies change', (tester) async {
      final rxA = TestReactive<String>('A');
      final rxB = TestReactive<String>('B');
      final toggle = TestReactive<bool>(true);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LWatch(() {
            if (toggle.value) {
              return Text(rxA.value);
            } else {
              return Text(rxB.value);
            }
          }),
        ),
      );

      expect(find.text('A'), findsOneWidget);

      toggle.value = false;
      await tester.pump();
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('LWatch debugLabel asserts', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LWatch(() {
            return Container();
          }, debugLabel: 'test_watch'),
        ),
      );
    });
  });
}
