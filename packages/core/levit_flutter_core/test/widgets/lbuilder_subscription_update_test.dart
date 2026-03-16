import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class TestReactive<T> extends LxVar<T> {
  TestReactive(super.initial);
}

void main() {
  group('LBuilder Subscription', () {
    testWidgets('LWatchVar watches specific reactive', (tester) async {
      final rx = TestReactive<int>(100);
      int buildCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LBuilder<int>(rx, (r) {
            buildCount++;
            return Text('V: ${r}');
          }),
        ),
      );

      expect(find.text('V: 100'), findsOneWidget);
      expect(buildCount, 1);

      rx.value = 200;
      await tester.pump();
      expect(find.text('V: 200'), findsOneWidget);
      expect(buildCount, 2);
    });

    testWidgets('LWatchVar updates subscription on widget update', (tester) async {
      final rx1 = TestReactive<int>(1);
      final rx2 = TestReactive<int>(2);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LBuilder<int>(
            rx1,
            (r) => Text('V: ${r}'),
            key: ValueKey('lvalue'),
          ),
        ),
      );

      expect(find.text('V: 1'), findsOneWidget);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LBuilder<int>(
            rx2,
            (r) => Text('V: ${r}'),
            key: ValueKey('lvalue'),
          ),
        ),
      );

      expect(find.text('V: 2'), findsOneWidget);

      rx1.value = 999;
      await tester.pump();
      expect(find.text('V: 2'), findsOneWidget);

      rx2.value = 3;
      await tester.pump();
      expect(find.text('V: 3'), findsOneWidget);
    });
  });
}
